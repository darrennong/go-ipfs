### GO-IPFS
#### 整体框架图
![IPFS](./src/cli-http-api-core-diagram.png)
#### 流程梳理
![IPFS学习](./src/IPFS-learn.jpg)

#### GO包安装
##### 常用方法
`go get -v -u golang.org/x/mobile/cmd/gomobile`
`go get -v -u github.com/golang/mobile`
转战`github`
然后将拉取下来的目录拷贝到`%GOPATH%/src/golang.org/`对应的目录下
`go build`, `go install`
可执行程序默认生成在`%GOPATH%/bin`目录下

#### GO跨平台
##### Android
* `gomobile build -target=android path` 将工程编译成apk, `adb install xxx`安装apk
* `gomobile bind -target=android testCounter` 将go包编译成aar库

#### TODOLIST
- [ ] 每个包的作用
- [ ] add的流程
- [ ] get的流程

 Package balanced provides methods to build balanced DAGs, which are generalistic
 DAGs in which all leaves (nodes representing chunks of data) are at the same
 distance from the root. Nodes can have only a maximum number of children; to be
 able to store more leaf data nodes balanced DAGs are extended by increasing its
 depth (and having more intermediary nodes).

 Internal nodes are always represented by UnixFS nodes (of type `File`) encoded
 inside DAG nodes (see the `go-unixfs` package for details of UnixFS). In
 contrast, leaf nodes with data have multiple possible representations: UnixFS
 nodes as above, raw nodes with just the file data (no format) and Filestore
 nodes (that directly link to the file on disk using a format stored on a raw
 node, see the `go-ipfs/filestore` package for details of Filestore.)

 In the case the entire file fits into just one node it will be formatted as a
 (single) leaf node (without parent) with the possible representations already
 mentioned. This is the only scenario where the root can be of a type different
 that the UnixFS node.

 Layout builds a balanced DAG layout. In a balanced DAG of depth 1, leaf nodes
 with data are added to a single `root` until the maximum number of links is
 reached. Then, to continue adding more data leaf nodes, a `newRoot` is created
 pointing to the old `root` (which will now become and intermediary node),
 increasing the depth of the DAG to 2. This will increase the maximum number of
 data leaf nodes the DAG can have (`Maxlinks() ^ depth`). The `fillNodeRec`
 function will add more intermediary child nodes to `newRoot` (which already has
 `root` as child) that in turn will have leaf nodes with data added to them.
 After that process is completed (the maximum number of links is reached),
 `fillNodeRec` will return and the loop will be repeated: the `newRoot` created
 will become the old `root` and a new root will be created again to increase the
 depth of the DAG. The process is repeated until there is no more data to add
 (i.e. the DagBuilderHelper’s Done() function returns true).

 The nodes are filled recursively, so the DAG is built from the bottom up. Leaf
 nodes are created first using the chunked file data and its size. The size is
 then bubbled up to the parent (internal) node, which aggregates all the sizes of
 its children and bubbles that combined size up to its parent, and so on up to
 the root. This way, a balanced DAG acts like a B-tree when seeking to a byte
 offset in the file the graph represents: each internal node uses the file size
 of its children as an index when seeking.
