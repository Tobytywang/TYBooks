import Database from 'better-sqlite3'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { existsSync } from 'fs'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

const dbPath = join(__dirname, '..', 'data', 'books.db')

const db = new Database(dbPath)

db.pragma('journal_mode = WAL')

db.exec(`
  CREATE TABLE IF NOT EXISTS books (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
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

const count = db.prepare('SELECT COUNT(*) as c FROM books').get()
if (count.c === 0) {
  const seedData = [
    { emoji: '📖', title: '百年孤独', author: '加西亚·马尔克斯', genre: '小说', status: 'done', rating: 5, review: '一个家族七代人的轮回。魔幻现实主义的巅峰之作，每个人都能在布恩迪亚家族中找到自己的影子。', tags: '文学' },
    { emoji: '📝', title: '活着', author: '余华', genre: '小说', status: 'reading', rating: 5, review: '人在极端苦难中如何活着。语言朴素，力量惊人。', tags: '' },
    { emoji: '🏔️', title: '挪威的森林', author: '村上春树', genre: '小说', status: 'done', rating: 4, review: '村上最温柔的一部。那些没法好好告别的人，最后都留在了那片森林里。', tags: '文学' },
    { emoji: '🎪', title: '围城', author: '钱钟书', genre: '小说', status: 'done', rating: 5, review: '城里的人想出去，城外的人想进来。钱钟书的幽默和洞察力无人能及。', tags: '文学' },
    { emoji: '🏯', title: '红楼梦', author: '曹雪芹', genre: '小说', status: 'done', rating: 5, review: '一部百科全书式的中国古典小说。每次重读都有新的发现。', tags: '文学' },
    { emoji: '🌊', title: '海边的卡夫卡', author: '村上春树', genre: '小说', status: 'reading', rating: 0, review: '隐喻和现实的交错，村上风格最浓郁的一部。', tags: '' },
    { emoji: '🗡️', title: '三体', author: '刘慈欣', genre: '小说', status: 'done', rating: 5, review: '中国科幻的里程碑。宇宙黑暗森林法则的想象力令人震撼。', tags: '科学' },
    { emoji: '🪐', title: '银河帝国', author: '阿西莫夫', genre: '小说', status: 'wish', rating: 0, review: '', tags: '' },
    { emoji: '🇨🇳', title: '平凡的世界', author: '路遥', genre: '小说', status: 'done', rating: 5, review: '一代人的奋斗史诗。朴实无华，却有着打动人心的力量。', tags: '' },
    { emoji: '🏛️', title: '战争与和平', author: '托尔斯泰', genre: '小说', status: 'wish', rating: 0, review: '', tags: '' },
    { emoji: '💻', title: '黑客与画家', author: 'Paul Graham', genre: '技术', status: 'reading', rating: 4, review: '硅谷创业教父的文集。关于编程、创意和财富创造，视角独特。', tags: '非虚构' },
    { emoji: '🏛️', title: '设计模式', author: 'GoF', genre: '技术', status: 'done', rating: 3, review: '四人组的经典之作。理解了设计模式的思维方式后，写代码确实更从容了。', tags: '' },
    { emoji: '🐚', title: 'Unix 编程艺术', author: 'Eric S. Raymond', genre: '技术', status: 'wish', rating: 0, review: '', tags: '哲学' },
    { emoji: '🗄️', title: '数据库系统概论', author: '王珊', genre: '技术', status: 'done', rating: 4, review: '国内数据库教材的经典。深入浅出，从理论到实践都讲得很清楚。', tags: '' },
    { emoji: '📘', title: 'JavaScript 高级程序设计', author: 'Nicholas Zakas', genre: '技术', status: 'done', rating: 4, review: '前端开发者的红宝书。全面系统的 JS 指南。', tags: '' },
    { emoji: '🐍', title: '流畅的 Python', author: 'Luciano Ramalho', genre: '技术', status: 'reading', rating: 4, review: '深入理解 Python 特性的必读之作。每章都有新收获。', tags: '' },
    { emoji: '🌐', title: 'HTTP 权威指南', author: 'David Gourley', genre: '技术', status: 'done', rating: 4, review: 'Web 开发者必读。理解了 HTTP 才能理解互联网的底层逻辑。', tags: '' },
    { emoji: '⚛️', title: 'React 设计原理', author: '卡颂', genre: '技术', status: 'done', rating: 4, review: '从源码层面理解 React 的设计哲学。', tags: '' },
    { emoji: '🤖', title: '人工智能', author: 'Russell & Norvig', genre: '技术', status: 'wish', rating: 0, review: '', tags: '科学' },
    { emoji: '🌍', title: '人类简史', author: '尤瓦尔·赫拉利', genre: '历史', status: 'done', rating: 5, review: '从认知革命到科学革命，重新理解人类走过的路。', tags: '非虚构' },
    { emoji: '🌏', title: '枪炮、病菌与钢铁', author: '贾雷德·戴蒙德', genre: '历史', status: 'wish', rating: 0, review: '', tags: '非虚构' },
    { emoji: '🏯', title: '万历十五年', author: '黄仁宇', genre: '历史', status: 'done', rating: 5, review: '以万历十五年为切片，展现大明帝国的运作逻辑。大历史观的典范。', tags: '' },
    { emoji: '📜', title: '史记', author: '司马迁', genre: '历史', status: 'done', rating: 5, review: '史家之绝唱，无韵之离骚。中国最好的历史著作，没有之一。', tags: '文学' },
    { emoji: '🏛️', title: '罗马帝国衰亡史', author: '吉本', genre: '历史', status: 'reading', rating: 0, review: '巨著！正在慢慢啃。', tags: '' },
    { emoji: '🌊', title: '全球通史', author: '斯塔夫里阿诺斯', genre: '历史', status: 'wish', rating: 0, review: '', tags: '' },
    { emoji: '🧠', title: '存在与时间', author: '海德格尔', genre: '哲学', status: 'wish', rating: 0, review: '', tags: '' },
    { emoji: '⚖️', title: '论人类不平等的起源', author: '卢梭', genre: '哲学', status: 'done', rating: 4, review: '薄薄一本，却影响深远。卢梭对人类文明进程的洞察，至今读来仍有强烈的现实感。', tags: '' },
    { emoji: '🎭', title: '查拉图斯特拉如是说', author: '尼采', genre: '哲学', status: 'done', rating: 4, review: '尼采最具诗意的作品。上帝死了，超人诞生。', tags: '' },
    { emoji: '🕰️', title: '纯粹理性批判', author: '康德', genre: '哲学', status: 'done', rating: 3, review: '西方哲学的分水岭。虽然难读，但每个认真读完的人都脱了一层皮。', tags: '' },
    { emoji: '🏺', title: '理想国', author: '柏拉图', genre: '哲学', status: 'reading', rating: 0, review: '西方哲学的源头，正在和苏格拉底对话。', tags: '' },
    { emoji: '📖', title: '中国哲学简史', author: '冯友兰', genre: '哲学', status: 'wish', rating: 0, review: '', tags: '' },
    { emoji: '🔬', title: '万物简史', author: '比尔·布莱森', genre: '科学', status: 'done', rating: 4, review: '用幽默的笔触写成的人类科学探索史。从宇宙大爆炸到DNA发现，精彩纷呈。', tags: '非虚构' },
    { emoji: '🧬', title: '自私的基因', author: '理查德·道金斯', genre: '科学', status: 'reading', rating: 0, review: '正在读，只能说——世界观正在被刷新。', tags: '非虚构' },
    { emoji: '⏳', title: '时间简史', author: '霍金', genre: '科学', status: 'done', rating: 4, review: '霍金让宇宙学变得可读。从大爆炸到黑洞，深入浅出。', tags: '' },
    { emoji: '🧪', title: '上帝掷骰子吗', author: '曹天元', genre: '科学', status: 'done', rating: 5, review: '中国最好的量子物理科普。既有科学的严谨，又有故事的精彩。', tags: '' },
    { emoji: '🌌', title: '宇宙的结构', author: '布莱恩·格林', genre: '科学', status: 'wish', rating: 0, review: '', tags: '' },
    { emoji: '💼', title: '穷查理宝典', author: '查理·芒格', genre: '商业', status: 'done', rating: 5, review: '芒格的普世智慧——用多学科思维模型做决策。不是投资书，是人生书。常读常新。', tags: '哲学' },
    { emoji: '📈', title: '从零到一', author: 'Peter Thiel', genre: '商业', status: 'done', rating: 4, review: '"竞争是留给失败者的"，这个观点值得反复咀嚼。', tags: '' },
    { emoji: '📊', title: '思考，快与慢', author: '丹尼尔·卡尼曼', genre: '商业', status: 'done', rating: 5, review: '系统1和系统2——理解自己的认知偏误，是理性决策的第一步。', tags: '非虚构' },
    { emoji: '🔄', title: '重新定义公司', author: 'Eric Schmidt', genre: '商业', status: 'done', rating: 4, review: 'Google 内部的管理哲学。创意精英这个概念很有启发。', tags: '' },
    { emoji: '🌱', title: '创新者的窘境', author: '克里斯坦森', genre: '商业', status: 'wish', rating: 0, review: '', tags: '' },
    { emoji: '✍️', title: '置身事内', author: '兰小欢', genre: '非虚构', status: 'done', rating: 5, review: '理解中国经济发展和政府角色最好的入门书之一。深入但不晦涩，实事求是。', tags: '商业' },
    { emoji: '📊', title: '事实', author: '汉斯·罗斯林', genre: '非虚构', status: 'done', rating: 4, review: '用数据治愈焦虑。每一页都在打脸你对世界的刻板印象。', tags: '科学' },
    { emoji: '🗣️', title: '非暴力沟通', author: '马歇尔·卢森堡', genre: '非虚构', status: 'done', rating: 4, review: '观察、感受、需要、请求——四个步骤改善所有关系。', tags: '' },
    { emoji: '🧘', title: '心流', author: '米哈里·契克森米哈赖', genre: '非虚构', status: 'reading', rating: 0, review: '最优体验的心理学。找到心流状态就是找到幸福。', tags: '哲学' },
    { emoji: '🌐', title: '信息简史', author: '詹姆斯·格雷克', genre: '非虚构', status: 'wish', rating: 0, review: '', tags: '技术' },
    { emoji: '🎭', title: '台北人', author: '白先勇', genre: '文学', status: 'done', rating: 5, review: '每一个短篇都是一部浓缩的民国史。白先勇的笔太细腻了。', tags: '小说' },
    { emoji: '📖', title: '边城', author: '沈从文', genre: '文学', status: 'done', rating: 5, review: '湘西水乡的爱情悲剧。沈从文的文字像清泉，干净透亮。', tags: '' },
    { emoji: '🌸', title: '雪国', author: '川端康成', genre: '文学', status: 'done', rating: 4, review: '日本文学中极致的物哀之美。「穿过县界长长的隧道，便是雪国。」', tags: '' },
    { emoji: '🏜️', title: '撒哈拉的故事', author: '三毛', genre: '文学', status: 'reading', rating: 0, review: '三毛笔下的沙漠生活，自由又浪漫。', tags: '' },
    { emoji: '🌿', title: '瓦尔登湖', author: '梭罗', genre: '文学', status: 'wish', rating: 0, review: '', tags: '哲学' },
    { emoji: '🌊', title: '追忆似水年华', author: '普鲁斯特', genre: '文学', status: 'wish', rating: 0, review: '', tags: '' },
  ]

  const insert = db.prepare(`
    INSERT INTO books (emoji, title, author, genre, status, rating, review, tags)
    VALUES (@emoji, @title, @author, @genre, @status, @rating, @review, @tags)
  `)

  const insertMany = db.transaction((rows) => {
    for (const row of rows) insert.run(row)
  })

  insertMany(seedData)
  console.log(`Seeded ${seedData.length} books`)
}

export default db
