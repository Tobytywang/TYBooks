const MAX_LOG_SIZE = 200
const serverLog = []

const origLog = console.log
const origWarn = console.warn
const origError = console.error

function record(level, args) {
  const msg = args.map(a => typeof a === 'string' ? a : JSON.stringify(a)).join(' ')
  serverLog.push({
    time: new Date().toISOString(),
    level,
    message: msg.length > 500 ? msg.slice(0, 500) + '...' : msg,
  })
  if (serverLog.length > MAX_LOG_SIZE) {
    serverLog.shift()
  }
}

console.log = function (...args) {
  record('info', args)
  origLog.apply(console, args)
}

console.warn = function (...args) {
  record('warn', args)
  origWarn.apply(console, args)
}

console.error = function (...args) {
  record('error', args)
  origError.apply(console, args)
}

export function getServerLog() {
  return [...serverLog]
}
