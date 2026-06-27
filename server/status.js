import { Router } from 'express'
import { poolRead } from './db.js'
import { authMiddleware } from './middleware/auth.js'
import { getQueryLog } from './middleware/queryLog.js'
import { getServerLog } from './middleware/serverLog.js'

const router = Router()

router.get('/status', authMiddleware, async (_req, res) => {
  const backend = {
    status: 'ok',
    uptime: Math.round(process.uptime()),
    nodeVersion: process.version,
    port: process.env.PORT || 8080,
  }

  let database
  try {
    const start = performance.now()
    const { rows: [{ version }] } = await poolRead.query('SELECT version()')
    const latency = Math.round((performance.now() - start) * 100) / 100
    const pool = poolRead
    database = {
      status: 'ok',
      latency,
      pgVersion: version.split(',')[0],
      poolTotal: pool.totalCount,
      poolIdle: pool.idleCount,
      poolWaiting: pool.waitingCount,
    }
  } catch (e) {
    database = {
      status: 'error',
      error: e.message,
    }
  }

  res.json({
    backend,
    database,
    queryLog: getQueryLog(),
    serverLog: getServerLog(),
  })
})

export default router
