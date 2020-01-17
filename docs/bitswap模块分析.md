# bitswap模块分析
- [bitswap](#bitswap)
- [wantmanager](#wantmanager)
- [session](#session)
    - [获取分片](#获取分片)
    - [定时器](#定时器)
- [sessionrequestsplitter](#sessionrequestsplitter)
    - [切割wantlist](#切割wantlist)
    - [split调整](#split调整)
- [下载加速方案](#下载加速方案)

本文档是基于`ipfs v0.4.19`版本，分析`bitswap`相比较之前的版本的改动。
本次`bitswap`模块升级可谓是变化巨大，更模块化。
模块之间全部使用管道(message)通信，定义各种`message`，将消息的处理从接收者中提取出来，更符合`开闭原则`。
最大的变化是引入`session`的概念，将之前的传输相关的功能从`wantmanager`中提取出来，使`wantmanager`从之前的臃肿不堪变成面向接口，非常好的将`实现`和`调度`解耦，使整个模块更加层次分明。
### bitswap
#### New()
```go
	wm := bswm.New(ctx)
	pqm := bspqm.New(ctx, network)

	sessionFactory := func(ctx context.Context, id uint64, pm bssession.PeerManager, srs bssession.RequestSplitter) bssm.Session {
		return bssession.New(ctx, id, wm, pm, srs)
	}
	sessionPeerManagerFactory := func(ctx context.Context, id uint64) bssession.PeerManager {
		return bsspm.New(ctx, id, network.ConnectionManager(), pqm)
	}
	sessionRequestSplitterFactory := func(ctx context.Context) bssession.RequestSplitter {
		return bssrs.New(ctx)
	}

	bs := &Bitswap{
		blockstore:    bstore,
		engine:        decision.NewEngine(ctx, bstore), // TODO close the engine with Close() method
		network:       network,
		process:       px,
		newBlocks:     make(chan cid.Cid, HasBlockBufferSize),
		provideKeys:   make(chan cid.Cid, provideKeysBufferSize),
		wm:            wm,
		pqm:           pqm,
		pm:            bspm.New(ctx, peerQueueFactory),
		sm:            bssm.New(ctx, sessionFactory, sessionPeerManagerFactory, sessionRequestSplitterFactory),
		counters:      new(counters),
		dupMetric:     dupHist,
		allMetric:     allHist,
		sentHistogram: sentHistogram,
	}

	bs.wm.SetDelegate(bs.pm)
	bs.wm.Startup()
	bs.pqm.Startup()
	network.SetDelegate(bs)
```
以上片段是`bitswap`的构造函数，可以看到有三个函数指针，这三个函数全部是初始化对象的作用，这样使`bitswap`看起来像一个工厂(factory)，用于生产各种对象。

### wantmanager
```go
type wantMessage interface {
	handle(wm *WantManager)
}

type connectedMessage struct {
	p peer.ID
}

func (cm *connectedMessage) handle(wm *WantManager) {
	wm.peerHandler.Connected(cm.p, wm.bcwl)
}

func (wm *WantManager) run() {
	for {
		select {
		case message := <-wm.wantMessages:
			message.handle(wm)
		case <-wm.ctx.Done():
			return
		}
	}
}
```
以上片段是`wantmanager.go`中比较大的改变，使用`channel`接收外部消息(wantMessage)，使用接口`handle()`处理消息，使拓展消息非常容易，且不用修改`wantmanager`。
这个改进是`开闭原则`的非常好的一个体现(对拓展开放，对修改关闭)。
这种通信模式在本次`bitswap`改进中有大量的使用。

### session
这个模块主要是封装对分片的处理。
#### 获取分片
```go
func (s *Session) wantBlocks(ctx context.Context, ks []cid.Cid) {
	now := time.Now()
	for _, c := range ks {
		s.liveWants[c] = now
    }
    // 查找节点
	peers := s.pm.GetOptimizedPeers()
	if len(peers) > 0 {
        // 切分节点和分片
		splitRequests := s.srs.SplitRequest(peers, ks)
		fmt.Println("Peers' Len > 0")
		for _, splitRequest := range splitRequests {
			fmt.Println("splitRequest peers", splitRequest.Peers)
			s.pm.RecordPeerRequests(splitRequest.Peers, splitRequest.Keys)
			s.wm.WantBlocks(ctx, splitRequest.Keys, splitRequest.Peers, s.id)
		}
	} else {
		fmt.Println("Peers' Len == 0")
		s.pm.RecordPeerRequests(nil, ks)
		s.wm.WantBlocks(ctx, ks, nil, s.id)
	}
}
```
这个模块还有一个大的升级是，加入了对下载过程中的`wantlist`的分配，也就是`ipfs`官方也意识到之前的下载方式的不合理，对此作的修正。
这个修正的大致原理跟我们之前的`ptfs加速原理`很类似，查找`provider`以及给不同的对等体分配不同的`wantlist`，只是分配的方案没有`ptfs加速原理`激进。该修正的详细信息在下文中介绍。

#### 定时器
```go
var provSearchDelay = time.Second

func (s *Session) run(ctx context.Context) {
	s.tick = time.NewTimer(provSearchDelay)
	for {
		select {
        ...
		case <-s.tick.C:
			s.handleTick(ctx)
		}
	}
}

func (s *Session) handleTick(ctx context.Context) {

	live := make([]cid.Cid, 0, len(s.liveWants))
	now := time.Now()
	for c := range s.liveWants {
		live = append(live, c)
		s.liveWants[c] = now
	}
	fmt.Println("handleTick")
	// Broadcast these keys to everyone we're connected to
	s.pm.RecordPeerRequests(nil, live)
	s.wm.WantBlocks(ctx, live, nil, s.id)

	if len(live) > 0 {
		s.pm.FindMorePeers(ctx, live[0])
	}
	s.resetTick()
}
```
以上代码片段可以看见该定时器的时长非常短，该定时器的作用有两个:
1. 查找节点
2. 将`wantlist`全部发出去

对该定时器的设计，官方作者的回复[question about provSearchDelay](https://github.com/ipfs/go-bitswap/issues/107).
这里关于2的做法我不太认同，将`wantlist`全部发出去仍然是对带宽的浪费。这里也是可以优化下载速度的点。

### sessionrequestsplitter
这个模块从名字可以看出，是专门处理请求的切分的，也就是`wantlist`的分配。
#### 切割wantlist
```go
func splitKeys(ks []cid.Cid, split int) [][]cid.Cid {
	splits := make([][]cid.Cid, split)
	for i, c := range ks {
		pos := i % split
		splits[pos] = append(splits[pos], c)
	}
	return splits
}

func splitPeers(peers []peer.ID, split int) [][]peer.ID {
	splits := make([][]peer.ID, split)
	for i, p := range peers {
		pos := i % split
		splits[pos] = append(splits[pos], p)
	}
	return splits
}
```
以上片段是分配`wantlist`的处理办法。将`wantlist`和`peers`(查找到的节点)分别切割成`split`份。
这里的处理方式还是有所保留，例如将4个peers切成2份，每份中的两个节点发送的`wantlist`还是一样的，没有`ptfs加速原理`这般激进。

#### split调整
```go
maxAcceptableDupes       = 0.4
minDuplesToTryLessSplits = 0.2

func (srs *SessionRequestSplitter) duplicateRatio() float64 {
	return float64(srs.duplicateReceivedCount) / float64(srs.receivedCount)
}

func (r *recordDuplicateMessage) handle(srs *SessionRequestSplitter) {
	srs.receivedCount++
	srs.duplicateReceivedCount++
	if (srs.receivedCount > minReceivedToAdjustSplit) && (srs.duplicateRatio() > maxAcceptableDupes) && (srs.split < maxSplit) {
		srs.split++
	}
}

func (r *recordUniqueMessage) handle(srs *SessionRequestSplitter) {
	srs.receivedCount++
	if (srs.split > 1) && (srs.duplicateRatio() < minDuplesToTryLessSplits) {
		srs.split--
	}
}
```
以上代码片段显示的是`split`(切分的份数)会动态调整，调整的依据是`duplicateRatio()`，该函数返回的是`收到分片的重复率`。
`ipfs`官方作者希望通过调整切分份数将重复率控制在`0.2-0.4`之间。
这里的优化思路跟我们之前的`ptfs加速原理`有所不同，我们是希望重复率越低越好，因为重复率越低意味着带宽利用率越高；而官方是希望将重复率控制在一个区间。
暂时还不太清楚官方这样作的用意以及该参数表征的意义，希望能得到官方的答复。

### 下载加速方案
比较欣喜的是官方已经对曾经的下载方法作出相当的优化，有意识的进行分片的分配。
我们在此基础上需要作的优化仍然是尽量减少重复率，尽量提高带宽利用率。
有优化空间的点:
1. 定时器触发函数
2. 切割wantlist方案
