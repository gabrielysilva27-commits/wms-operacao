export function standardSeconds({baseSeconds,boxes,secondsPerBox,meters,secondsPerMeter}) {
 const values=[baseSeconds,boxes,secondsPerBox,meters,secondsPerMeter];
 if(values.some(x=>!Number.isFinite(x)||x<0)) throw new Error('Invalid effort input');
 return Math.ceil(baseSeconds+boxes*secondsPerBox+meters*secondsPerMeter);
}
// Proposed calibration only: supervisor publishes a new immutable model after review.
export function calibration(samples) {
 const valid=samples.filter(s=>s.actualSeconds>0&&s.standardSeconds>0&&s.complete&&!s.hasOpenIssue);
 if(valid.length<30) return {status:'insufficient_samples',sampleCount:valid.length};
 const ratios=valid.map(s=>s.actualSeconds/s.standardSeconds).sort((a,b)=>a-b);
 const mid=Math.floor(ratios.length/2);
 return {status:'review_required',sampleCount:valid.length,factor:ratios.length%2?ratios[mid]:(ratios[mid-1]+ratios[mid])/2};
}
