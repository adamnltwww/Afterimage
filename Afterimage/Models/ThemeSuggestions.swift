import Foundation
import NaturalLanguage

/// Conservative, offline suggestions. Existing names win over creating synonyms.
enum ThemeSuggestions {
    private static let vocabulary: [(String, [String])] = [
        ("摄影", ["摄影", "拍照", "拍摄", "快门", "镜头", "相机", "拍日出", "拍日落", "photography", "camera"]),
        ("读书", ["读书", "阅读", "书页", "读完", "看书", "书店", "reading"]),
        ("音乐", ["音乐", "听歌", "一首歌", "那首歌", "专辑", "演出", "演唱会", "music"]),
        ("旅行", ["旅行", "旅途", "旅游", "出游", "列车", "明信片", "travel"]),
        ("朋友", ["朋友", "好友", "老友", "聚会", "friend", "friends"]),
        ("家人", ["家人", "爸妈", "爸爸", "妈妈", "父母", "family"]),
        ("咖啡", ["咖啡", "coffee", "café", "cafe"]),
        ("湖边", ["湖边", "湖畔", "湖面", "lake", "lakeside"]),
        ("海边", ["海边", "海滩", "海浪", "沙滩", "beach", "seaside"]),
        ("散步", ["散步", "漫步", "遛弯", "stroll"]),
        ("城市", ["城市", "街口", "街道", "小巷", "city"]),
        ("美食", ["美食", "下厨", "做饭", "晚餐", "午餐", "早餐", "料理"]),
        ("运动", ["运动", "跑步", "游泳", "健身", "骑行", "徒步", "workout"]),
        ("工作", ["工作", "加班", "同事", "下班", "上班"]),
        ("学习", ["学习", "复习", "考试", "作业", "课堂", "课程", "study"]),
        ("花草", ["花草", "花开", "开花", "鲜花", "花园", "花瓣", "樱花", "玫瑰", "郁金香", "荷花", "梅花", "桂花", "向日葵", "flower", "flowers"]),
        ("植物", ["植物", "绿植", "盆栽", "多肉", "蕨类", "苔藓", "树叶", "银杏", "枫叶", "plant", "plants"]),
        ("山野", ["山野", "登山", "爬山", "山顶", "山谷", "山间", "山峰", "mountain", "mountains"]),
        ("森林", ["森林", "树林", "林间", "竹林", "forest", "woods"]),
        ("河流", ["河流", "河边", "河岸", "江边", "溪流", "小溪", "river", "stream"]),
        ("日出日落", ["日出", "日落", "夕阳", "晚霞", "朝霞", "落日", "sunrise", "sunset"]),
        ("天空", ["天空", "云层", "云海", "蓝天", "白云", "彩虹", "sky", "clouds", "rainbow"]),
        ("雨天", ["雨天", "下雨", "雨后", "雨滴", "雨声", "暴雨", "小雨", "梅雨", "rain", "rainy"]),
        ("雪天", ["下雪", "雪天", "雪花", "积雪", "初雪", "雪景", "snow", "snowy"]),
        ("夜晚", ["夜晚", "深夜", "夜里", "夜色", "夜景", "月亮", "月光", "星空", "星星", "night", "moon", "stars"]),
        ("春天", ["春天", "春日", "春风", "踏青", "spring"]),
        ("夏天", ["夏天", "夏日", "夏至", "盛夏", "蝉鸣", "summer"]),
        ("秋天", ["秋天", "秋日", "深秋", "秋风", "autumn"]),
        ("冬天", ["冬天", "冬日", "冬至", "寒冬", "winter"]),
        ("露营", ["露营", "帐篷", "野餐", "篝火", "camping", "picnic"]),
        ("宠物", ["宠物", "猫咪", "小猫", "猫猫", "撸猫", "小狗", "狗狗", "遛狗", "喵", "kitten", "puppy", "cat", "dog", "pet"]),
        ("动物", ["动物", "观鸟", "飞鸟", "小鸟", "海鸥", "蝴蝶", "松鼠", "bird", "birds", "butterfly"]),
        ("电影", ["电影", "影院", "观影", "纪录片", "导演", "movie", "cinema", "film"]),
        ("展览", ["展览", "看展", "画展", "美术馆", "博物馆", "艺术馆", "策展", "exhibition", "museum", "gallery"]),
        ("绘画", ["绘画", "画画", "水彩", "素描", "油画", "速写", "插画", "painting", "drawing"]),
        ("手作", ["手作", "手工", "编织", "陶艺", "陶土", "刺绣", "木工", "拼贴", "craft", "pottery"]),
        ("书写", ["书写", "日记", "写字", "写信", "书法", "钢笔", "手帐", "手账", "journal", "writing"]),
        ("游戏", ["游戏", "通关", "桌游", "电玩", "电竞", "game", "gaming"]),
        ("数码", ["数码", "电脑", "键盘", "耳机", "平板", "手机", "computer", "keyboard"]),
        ("编程", ["编程", "代码", "调试", "程序", "开发", "算法", "coding", "programming", "debug"]),
        ("烘焙", ["烘焙", "烤箱", "面包", "蛋糕", "饼干", "可颂", "baking", "bread", "cake"]),
        ("茶", ["喝茶", "泡茶", "茶馆", "茶叶", "乌龙", "红茶", "绿茶", "普洱", "抹茶", "tea"]),
        ("甜品", ["甜品", "甜点", "冰淇淋", "冰激凌", "布丁", "奶茶", "巧克力", "dessert"]),
        ("居家", ["居家", "宅家", "打扫", "收纳", "整理房间", "搬家", "装修", "布置房间"]),
        ("购物", ["购物", "逛街", "商场", "买衣服", "市集", "集市", "shopping", "market"]),
        ("校园", ["校园", "学校", "教室", "宿舍", "同学", "毕业", "开学", "school", "campus"]),
        ("生日", ["生日", "birthday"]),
        ("节日", ["节日", "春节", "过年", "中秋", "端午", "元宵", "圣诞", "跨年", "国庆", "元旦", "christmas", "festival"]),
        ("纪念", ["纪念", "周年", "纪念日", "anniversary"]),
        ("重逢", ["重逢", "重聚", "再见面", "久别", "reunion"]),
        ("告别", ["告别", "离别", "送别", "道别", "farewell"]),
        ("想念", ["想念", "思念", "怀念", "惦记"]),
        ("独处", ["独处", "一个人", "独自", "alone", "solitude"]),
        ("放松", ["放松", "休息", "放空", "发呆", "悠闲", "relax"]),
        ("小确幸", ["开心", "高兴", "惊喜", "幸福", "快乐", "幸运", "满足", "happy"]),
        ("低落", ["低落", "难过", "失落", "伤心", "沮丧", "委屈", "sad"]),
        ("焦虑", ["焦虑", "紧张", "忐忑", "不安", "压力", "anxious"]),
        ("成长", ["成长", "突破", "学会", "第一次", "勇气", "坚持"]),
        ("健康", ["健康", "体检", "生病", "感冒", "康复", "医院", "看病"]),
        ("通勤", ["通勤", "地铁", "公交", "早高峰", "晚高峰", "末班车", "subway", "commute"]),
        ("骑行", ["骑行", "骑车", "自行车", "单车", "cycling", "bicycle"]),
        ("跑步", ["跑步", "晨跑", "夜跑", "马拉松", "running", "marathon"]),
        ("球类", ["篮球", "足球", "羽毛球", "乒乓球", "网球", "排球", "台球", "basketball", "football", "tennis"])
    ]

    static func names(title: String, text: String, existing: [String], limit: Int = 3) -> [String] {
        guard limit > 0 else { return [] }
        let heading = normalize(title)
        let body = normalize(String(text.prefix(4000)))
        var candidates: [(name: String, score: Int, existing: Bool)] = []
        let known = TagInput.names(from: existing.sorted().joined(separator: "、"))
        for name in known {
            let term = normalize(name)
            let aliases = vocabulary.first { normalize($0.0) == term || $0.1.contains(where: { normalize($0) == term }) }?.1 ?? []
            let words = [name] + aliases
            let score = words.contains(where: { contains($0, in: heading) }) ? 20 : words.contains(where: { contains($0, in: body) }) ? 10 : 0
            if score > 0 { candidates.append((name, score, true)) }
        }
        for (name, words) in vocabulary {
            // Reuse the user's equivalent theme, including its spelling and color.
            guard !known.contains(where: { knownName in
                normalize(knownName) == normalize(name) || words.contains(where: { normalize($0) == normalize(knownName) })
            }) else { continue }
            let score = words.contains(where: { contains($0, in: heading) }) ? 20 : words.contains(where: { contains($0, in: body) }) ? 10 : 0
            if score > 0 { candidates.append((name, score, false)) }
        }
        if candidates.isEmpty {
            return Array(keywords(from: title + "\n" + text).prefix(min(limit, 2)))
        }
        return candidates.sorted {
            if $0.existing != $1.existing { return $0.existing }
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.name < $1.name
        }.prefix(limit).map(\.name)
    }

    private static let stopWords: Set<String> = ["今天", "昨天", "明天", "现在", "时候", "时间", "事情", "东西", "感觉", "自己", "大家", "这个", "那个", "什么", "一些", "一下", "一天", "一点", "这里", "那里", "最近", "终于", "真的", "好像", "已经", "还是", "然后", "所以", "但是", "因为", "可以", "没有", "不是", "就是", "我们", "你们", "他们", "一个", "怎么", "这样", "那样", "觉得", "看到", "遇到", "发现", "有点", "很多", "非常", "特别", "比较", "可能", "应该", "其实", "嗯", "哈哈", "呵呵", "today", "yesterday", "tomorrow", "thing", "things", "time", "something", "the", "and", "but", "for", "with", "from", "this", "that", "these", "those", "was", "were", "are", "have", "has", "had", "not", "very", "just", "some", "any", "really", "went", "got", "get", "made", "make", "can", "could", "would", "should", "will", "then", "than", "when", "where", "what", "how", "why", "who", "you", "your", "our", "they", "them", "their", "she", "her", "him", "his", "its", "about", "into", "after", "before", "again", "there", "here", "also", "been", "being", "did", "does", "doing", "felt", "feel"]

    private static func keywords(from text: String) -> [String] {
        let content = String(text.prefix(4000))
        let tagger = NLTagger(tagSchemes: [.nameTypeOrLexicalClass])
        tagger.string = content
        var result: [String] = []
        var seen = Set<String>()
        tagger.enumerateTags(in: content.startIndex..<content.endIndex, unit: .word,
                             scheme: .nameTypeOrLexicalClass, options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
            guard tag == .noun || tag == .placeName || tag == .organizationName else { return true }
            let word = String(content[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalize(word)
            guard (2...20).contains(word.count), !stopWords.contains(key),
                  word.rangeOfCharacter(from: .letters) != nil, seen.insert(key).inserted else { return true }
            result.append(word)
            return result.count < 2
        }
        // Some devices/languages have no lexical model installed. Tokenization still
        // works locally; use filtered words rather than requiring a model download.
        if result.isEmpty {
            let tokenizer = NLTokenizer(unit: .word)
            tokenizer.string = content
            tokenizer.enumerateTokens(in: content.startIndex..<content.endIndex) { range, _ in
                let word = String(content[range])
                let key = normalize(word)
                let minimum = word.unicodeScalars.allSatisfy(\.isASCII) ? 3 : 2
                guard (minimum...20).contains(word.count), !stopWords.contains(key),
                      word.unicodeScalars.allSatisfy({ CharacterSet.letters.contains($0) }),
                      seen.insert(key).inserted else { return true }
                result.append(word)
                return result.count < 2
            }
        }
        return result
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }

    private static func contains(_ word: String, in content: String) -> Bool {
        let term = normalize(word)
        guard !term.isEmpty else { return false }
        // Latin words must be whole words: "lake" must not match "Blake".
        if term.unicodeScalars.allSatisfy({ $0.isASCII }) {
            return content.range(of: "(?<![\\p{L}\\p{N}])" + NSRegularExpression.escapedPattern(for: term) + "(?![\\p{L}\\p{N}])", options: .regularExpression) != nil
        }
        return content.contains(term)
    }
}
