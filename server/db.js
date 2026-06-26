import pg from 'pg'
import bcrypt from 'bcryptjs'

const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://tybooks:tybooks@localhost:5432/tybooks',
})

const readOnlyUrl = process.env.DATABASE_URL_READONLY || process.env.DATABASE_URL || 'postgresql://tybooks:tybooks@localhost:5432/tybooks'
const poolRead = new pg.Pool({
  connectionString: readOnlyUrl,
})

async function initDB() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS books (
      id SERIAL PRIMARY KEY,
      emoji TEXT NOT NULL DEFAULT '📖',
      title TEXT NOT NULL,
      author TEXT NOT NULL,
      genre TEXT NOT NULL,
      status TEXT NOT NULL DEFAULT 'wish',
      rating INTEGER DEFAULT 0,
      review TEXT DEFAULT '',
      tags TEXT DEFAULT ''
    )
  `)

  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username TEXT NOT NULL UNIQUE,
      password TEXT NOT NULL
    )
  `)

  await pool.query(`
    CREATE TABLE IF NOT EXISTS genres (
      id SERIAL PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      color TEXT NOT NULL DEFAULT 'var(--c-other)',
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  `)

  const { rows: [{ c: userCount }] } = await pool.query('SELECT COUNT(*) as c FROM users')
  if (Number(userCount) === 0) {
    const hash = bcrypt.hashSync('admin123', 12)
    await pool.query('INSERT INTO users (username, password) VALUES ($1, $2) ON CONFLICT DO NOTHING', ['admin', hash])
    console.log('Created default admin user (username: admin, password: admin123)')
  }

  const { rows: [{ c: genreCount }] } = await pool.query('SELECT COUNT(*) as c FROM genres')
  if (Number(genreCount) === 0) {
    const genreSeed = [
      ['小说', 'var(--c-novel)', 1],
      ['技术', 'var(--c-tech)', 2],
      ['历史', 'var(--c-history)', 3],
      ['哲学', 'var(--c-philosophy)', 4],
      ['科学', 'var(--c-science)', 5],
      ['商业', 'var(--c-business)', 6],
      ['非虚构', 'var(--c-nonfic)', 7],
      ['文学', 'var(--c-literature)', 8],
      ['艺术', 'var(--c-art)', 9],
      ['传记', 'var(--c-biography)', 10],
      ['其他', 'var(--c-other)', 99],
    ]
    for (const [name, color, sort_order] of genreSeed) {
      await pool.query('INSERT INTO genres (name, color, sort_order) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING', [name, color, sort_order])
    }
    console.log(`Seeded ${genreSeed.length} genres`)
  }

  const { rows: [{ c: bookCount }] } = await pool.query('SELECT COUNT(*) as c FROM books')
  if (Number(bookCount) === 0) {
    const seedData = [
      ['📖', '百年孤独', '加西亚·马尔克斯', '小说', 'done', 5, '一个家族七代人的轮回。魔幻现实主义的巅峰之作，每个人都能在布恩迪亚家族中找到自己的影子。', '文学'],
      ['📝', '活着', '余华', '小说', 'reading', 5, '人在极端苦难中如何活着。语言朴素，力量惊人。', ''],
      ['🏔️', '挪威的森林', '村上春树', '小说', 'done', 4, '村上最温柔的一部。那些没法好好告别的人，最后都留在了那片森林里。', '文学'],
      ['🎪', '围城', '钱钟书', '小说', 'done', 5, '城里的人想出去，城外的人想进来。钱钟书的幽默和洞察力无人能及。', '文学'],
      ['🏯', '红楼梦', '曹雪芹', '小说', 'done', 5, '一部百科全书式的中国古典小说。每次重读都有新的发现。', '文学'],
      ['🌊', '海边的卡夫卡', '村上春树', '小说', 'reading', 0, '隐喻和现实的交错，村上风格最浓郁的一部。', ''],
      ['🗡️', '三体', '刘慈欣', '小说', 'done', 5, '中国科幻的里程碑。宇宙黑暗森林法则的想象力令人震撼。', '科学'],
      ['🪐', '银河帝国', '阿西莫夫', '小说', 'wish', 0, '', ''],
      ['🇨🇳', '平凡的世界', '路遥', '小说', 'done', 5, '一代人的奋斗史诗。朴实无华，却有着打动人心的力量。', ''],
      ['🏛️', '战争与和平', '托尔斯泰', '小说', 'wish', 0, '', ''],
      ['💻', '黑客与画家', 'Paul Graham', '技术', 'reading', 4, '硅谷创业教父的文集。关于编程、创意和财富创造，视角独特。', '非虚构'],
      ['🏛️', '设计模式', 'GoF', '技术', 'done', 3, '四人组的经典之作。理解了设计模式的思维方式后，写代码确实更从容了。', ''],
      ['🐚', 'Unix 编程艺术', 'Eric S. Raymond', '技术', 'wish', 0, '', '哲学'],
      ['🗄️', '数据库系统概论', '王珊', '技术', 'done', 4, '国内数据库教材的经典。深入浅出，从理论到实践都讲得很清楚。', ''],
      ['📘', 'JavaScript 高级程序设计', 'Nicholas Zakas', '技术', 'done', 4, '前端开发者的红宝书。全面系统的 JS 指南。', ''],
      ['🐍', '流畅的 Python', 'Luciano Ramalho', '技术', 'reading', 4, '深入理解 Python 特性的必读之作。每章都有新收获。', ''],
      ['🌐', 'HTTP 权威指南', 'David Gourley', '技术', 'done', 4, 'Web 开发者必读。理解了 HTTP 才能理解互联网的底层逻辑。', ''],
      ['⚛️', 'React 设计原理', '卡颂', '技术', 'done', 4, '从源码层面理解 React 的设计哲学。', ''],
      ['🤖', '人工智能', 'Russell & Norvig', '技术', 'wish', 0, '', '科学'],
      ['🌍', '人类简史', '尤瓦尔·赫拉利', '历史', 'done', 5, '从认知革命到科学革命，重新理解人类走过的路。', '非虚构'],
      ['🌏', '枪炮、病菌与钢铁', '贾雷德·戴蒙德', '历史', 'wish', 0, '', '非虚构'],
      ['🏯', '万历十五年', '黄仁宇', '历史', 'done', 5, '以万历十五年为切片，展现大明帝国的运作逻辑。大历史观的典范。', ''],
      ['📜', '史记', '司马迁', '历史', 'done', 5, '史家之绝唱，无韵之离骚。中国最好的历史著作，没有之一。', '文学'],
      ['🏛️', '罗马帝国衰亡史', '吉本', '历史', 'reading', 0, '巨著！正在慢慢啃。', ''],
      ['🌊', '全球通史', '斯塔夫里阿诺斯', '历史', 'wish', 0, '', ''],
      ['🧠', '存在与时间', '海德格尔', '哲学', 'wish', 0, '', ''],
      ['⚖️', '论人类不平等的起源', '卢梭', '哲学', 'done', 4, '薄薄一本，却影响深远。卢梭对人类文明进程的洞察，至今读来仍有强烈的现实感。', ''],
      ['🎭', '查拉图斯特拉如是说', '尼采', '哲学', 'done', 4, '尼采最具诗意的作品。上帝死了，超人诞生。', ''],
      ['🕰️', '纯粹理性批判', '康德', '哲学', 'done', 3, '西方哲学的分水岭。虽然难读，但每个认真读完的人都脱了一层皮。', ''],
      ['🏺', '理想国', '柏拉图', '哲学', 'reading', 0, '西方哲学的源头，正在和苏格拉底对话。', ''],
      ['📖', '中国哲学简史', '冯友兰', '哲学', 'wish', 0, '', ''],
      ['🔬', '万物简史', '比尔·布莱森', '科学', 'done', 4, '用幽默的笔触写成的人类科学探索史。从宇宙大爆炸到DNA发现，精彩纷呈。', '非虚构'],
      ['🧬', '自私的基因', '理查德·道金斯', '科学', 'reading', 0, '正在读，只能说——世界观正在被刷新。', '非虚构'],
      ['⏳', '时间简史', '霍金', '科学', 'done', 4, '霍金让宇宙学变得可读。从大爆炸到黑洞，深入浅出。', ''],
      ['🧪', '上帝掷骰子吗', '曹天元', '科学', 'done', 5, '中国最好的量子物理科普。既有科学的严谨，又有故事的精彩。', ''],
      ['🌌', '宇宙的结构', '布莱恩·格林', '科学', 'wish', 0, '', ''],
      ['💼', '穷查理宝典', '查理·芒格', '商业', 'done', 5, '芒格的普世智慧——用多学科思维模型做决策。不是投资书，是人生书。常读常新。', '哲学'],
      ['📈', '从零到一', 'Peter Thiel', '商业', 'done', 4, '"竞争是留给失败者的"，这个观点值得反复咀嚼。', ''],
      ['📊', '思考，快与慢', '丹尼尔·卡尼曼', '商业', 'done', 5, '系统1和系统2——理解自己的认知偏误，是理性决策的第一步。', '非虚构'],
      ['🔄', '重新定义公司', 'Eric Schmidt', '商业', 'done', 4, 'Google 内部的管理哲学。创意精英这个概念很有启发。', ''],
      ['🌱', '创新者的窘境', '克里斯坦森', '商业', 'wish', 0, '', ''],
      ['✍️', '置身事内', '兰小欢', '非虚构', 'done', 5, '理解中国经济发展和政府角色最好的入门书之一。深入但不晦涩，实事求是。', '商业'],
      ['📊', '事实', '汉斯·罗斯林', '非虚构', 'done', 4, '用数据治愈焦虑。每一页都在打脸你对世界的刻板印象。', '科学'],
      ['🗣️', '非暴力沟通', '马歇尔·卢森堡', '非虚构', 'done', 4, '观察、感受、需要、请求——四个步骤改善所有关系。', ''],
      ['🧘', '心流', '米哈里·契克森米哈赖', '非虚构', 'reading', 0, '最优体验的心理学。找到心流状态就是找到幸福。', '哲学'],
      ['🌐', '信息简史', '詹姆斯·格雷克', '非虚构', 'wish', 0, '', '技术'],
      ['🎭', '台北人', '白先勇', '文学', 'done', 5, '每一个短篇都是一部浓缩的民国史。白先勇的笔太细腻了。', '小说'],
      ['📖', '边城', '沈从文', '文学', 'done', 5, '湘西水乡的爱情悲剧。沈从文的文字像清泉，干净透亮。', ''],
      ['🌸', '雪国', '川端康成', '文学', 'done', 4, '日本文学中极致的物哀之美。「穿过县界长长的隧道，便是雪国。」', ''],
      ['🏜️', '撒哈拉的故事', '三毛', '文学', 'reading', 0, '三毛笔下的沙漠生活，自由又浪漫。', ''],
      ['🌿', '瓦尔登湖', '梭罗', '文学', 'wish', 0, '', '哲学'],
      ['🌊', '追忆似水年华', '普鲁斯特', '文学', 'wish', 0, '', ''],
    ]

    for (const [emoji, title, author, genre, status, rating, review, tags] of seedData) {
      await pool.query(
        'INSERT INTO books (emoji, title, author, genre, status, rating, review, tags) VALUES ($1, $2, $3, $4, $5, $6, $7, $8) ON CONFLICT DO NOTHING',
        [emoji, title, author, genre, status, rating, review, tags]
      )
    }
    console.log(`Seeded ${seedData.length} books`)
  }
}

export { pool, poolRead, initDB }
