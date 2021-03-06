# Weave
# Copyright (c) 2019 Mamy André-Ratsimbazafy
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at http://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at http://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  weave/[parallel_tasks, parallel_for, parallel_for_staged, runtime, runtime_fsm, await_fsm],
  weave/datatypes/flowvars,
  weave/channels/pledges

export
  Flowvar, Weave,
  spawn, sync, syncRoot,
  parallelFor, parallelForStrided,
  init, exit,
  loadBalance,
  isSpawned,
  getThreadId,
  # Experimental threadlocal prologue/epilogue
  parallelForStaged, parallelForStagedStrided,
  # Experimental dataflow parallelism
  spawnDelayed, Pledge,
  fulfill, newPledge

# TODO, those are workaround for not binding symbols in spawn macro
import weave/contexts
export
  readyWith, forceFuture,
  isRootTask
