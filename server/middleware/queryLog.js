const MAX_LOG_SIZE = 200
const queryLog = []

let queryCounter = 0

function recordQuery(sql, duration) {
  queryCounter++
  queryLog.push({
    id: queryCounter,
    time: new Date().toISOString(),
    sql: sql.length > 200 ? sql.slice(0, 200) + '...' : sql,
    duration: Math.round(duration * 100) / 100,
  })
  if (queryLog.length > MAX_LOG_SIZE) {
    queryLog.shift()
  }
}

export function wrapPool(pool) {
  const origQuery = pool.query.bind(pool)
  pool.query = function (...args) {
    const start = performance.now()
    const result = origQuery(...args)
    if (result && typeof result.then === 'function') {
      return result.then(res => {
        recordQuery(typeof args[0] === 'string' ? args[0] : args[0]?.text || '', performance.now() - start)
        return res
      }).catch(err => {
        recordQuery(typeof args[0] === 'string' ? args[0] : args[0]?.text || '', performance.now() - start)
        throw err
      })
    }
    return result
  }
  return pool
}

export function getQueryLog() {
  return [...queryLog]
}
