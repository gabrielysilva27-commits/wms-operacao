export type Adapter = 'romaneio' | 'cora' | 'ocp' | 'promax';
export type JobState = 'disabled'|'queued'|'running'|'retry_wait'|'succeeded'|'dead'|'manual_review';
export interface PromaxPayloadV1 {
 version: 1; operation: '03.11.20.carga_montada'|'03.11.20.carregamento';
 warehouseId: string; loadId: string; mapCode: string; plate: string;
 returnableAssets: Array<{code:string;quantity:number;unit:string}>;
 expectedRevision: number; evidenceIds: string[];
}
export interface AgentAdapter<T> {
 readonly name: Adapter;
 validate(payload:unknown): T;
 // Query before execution and after any timeout. Uncertain outcomes require manual review.
 reconcile(payload:T): Promise<'confirmed'|'not_applied'|'uncertain'>;
 execute(payload:T, context:{jobId:string;leaseToken:string;idempotencyKey:string}): Promise<{externalReceipt:string}>;
}
// Promax deliberately has no implementation. No browser control or credentials here.
