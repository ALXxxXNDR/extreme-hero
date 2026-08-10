export type PatchId =
  | 'multithread'
  | 'firewall'
  | 'overclock'
  | 'cache'
  | 'recursion'
  | 'targeting'
  | 'rollback'
  | 'hotfix'

export interface PatchModule {
  id: PatchId
  code: string
  name: string
  symbol: string
  mergeTitle: string
  mergeDescription: string
  debtTitle: string
  debtDescription: string
}

export type RunState = 'ready' | 'playing' | 'choosing' | 'boss' | 'won' | 'lost'
