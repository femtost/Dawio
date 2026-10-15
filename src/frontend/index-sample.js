// Async lock
function newLock(){
    var unlock,lock=new Promise((res,rej)=>{ unlock=res; });
    return [lock,unlock];
}

// Main
async function main(){
    // Test lock
    var [lock,unlock] = newLock();
    unlock();
    await lock;
}
window.addEventListener("load",main);