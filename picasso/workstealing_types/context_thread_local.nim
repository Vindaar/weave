# Project Picasso
# Copyright (c) 2019 Mamy André-Ratsimbazafy
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  ./bounded_queues, ./sync_types,
  ../memory/object_pools

# Thread-local context
# ----------------------------------------------------------------------------------

type
  Worker = object
    ## Distributed binary tree
    ##
    ## Each worker/thread is a node ID that will determine
    ## its parent and the children it oversees if any
    ##
    ## a node N will have as a left child node N*2+1
    ## and as a right child node N*2+2
    ##
    ## This tree tracks if workers backed off from stealing
    ## if they didn't find any task and now take a passive role:
    ## waiting for tasks to be shared instead of actively stealing.
    ##
    ## This is a "thread-local" structure, updates are received asynchronously
    ## via the StealRequest channel.

    # ⚠️ : We use 0-based indexing if you are familiar with binary tree
    #      indexed from 1, this is the correspondance table
    #                  root at 0    root at 1
    # Left child        ix*2 + 1     ix*2
    # Right child       ix*2 + 2     ix*2 + 1
    # Parent            (ix-1)/2     ix/2
    ID*: WorkerID
    leftChild*: WorkerID
    rightChild*: WorkerID
    isLeftChildIdle*: bool
    isRightChildIdle*: bool
    parent* WorkerID
    workSharingRequests*: BoundedQueue[2, StealRequest]
    deque*: PrellDeque[Task]
    currentTask*: Task

  Thefts = object
    ## Thief state
    # Outstanding steal requests [0, MaxSteal]
    requested: int
    # Before a worker can become quiescent it has to drop MaxSteal - 1
    # steal request and send the remaining one to its parent
    dropped: int
    victims: seq[WorkerID]
    when defined(StealLastVictim):
      lastVictim: WorkerID
    when defined(StealLastThief):
      lastThief: WorkerID

  TLContext* = object
    ## Thread-Local context
    rng*: uint32 # TODO: use Nim random
    worker*: Worker
    thefts*: Thefts
    taskCache*: IntrusiveStack[Task]
    taskChannelPool*: ObjectPool[PicassoMaxSteal, ChannelSpscSingle[Task]]
    counters*: Counters

  Counters* = object
    tasksExec*: int
    tasksExecRecently*: int
    tasksSent*: int
    tastsSplit*: int
    stealRequestsSent*: int
    stealRequestsHandled*: int
    stealRequestsDeclined*: int
    when defined(PicassoStealBackoff):
      stealRequestsResent*: int
    when StealStrategy == StealKind.adaptative:
      stealRequestsOne*: int
      stealRequestsHalf*: int
    when defined(PicassoLazyFutures):
      futuresConverted*: int

func leftChild(ID, maxID: WorkerID): WorkerID {.inline.} =
  assert ID >= 0 and maxID >= 0
  assert w.ID <= maxID

  result = 2*w.ID + 1
  if result > maxID:
    result = -1

func rightChild(ID, maxID: WorkerID): WorkerID {.inline.} =
  assert ID >= 0 and maxID >= 0
  assert ID <= maxID

  result = *ID + 2
  if result > maxID:
    result = -1

func parent(ID: Worker): int32 {.inline.} =
  (w.ID - 1) shr 1

func initialize*(w: var Worker, ID, maxID: WorkerID) =
  tree.leftChild = leftChild(ID, maxID)
  tree.rightChild = rightChild(ID, maxID)
  tree.parent = parent(ID)

  if tree.leftChild == -1:
    tree.isLeftChildIdle = true
  if tree.rightChild == -1
    tree.isRightChildIdle = true
