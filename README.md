# Caipiao Predictor

这个目录包含一个原生 SwiftUI macOS 彩票预测工作台，以及按彩种拆分的数据抓取/分析脚本。

重要提醒：彩票开奖结果应视为独立随机事件。这里的“预测”是统计建模和回测练习，不是中奖承诺，也不建议用它做超预算投注。

## 当前数据源

- 主数据源：中彩网前端使用的 JSONP 接口 `https://jc.zhcw.com/port/client_json.php`
- 备份数据源：广东省福利彩票发行中心静态历史页 `https://www.gdfc.org.cn/play_list_game_10.html`
- 规则口径：中国福彩网/中彩网公开的快乐8规则与奖级信息

## 项目结构

- `CaipiaoPredictor/`：原生 SwiftUI macOS 应用源码和 SwiftPM 配置
- `scripts/kl8/`：快乐8抓取与分析脚本
- `data/kl8/`：快乐8历史开奖数据
- `outputs/kl8/`：快乐8分析输出
- `build/`：最终构建产物，例如 `Caipiao Predictor.app`

新增彩种时，建议按同样结构扩展，例如 `scripts/ssq/`、`data/ssq/`、`outputs/ssq/`。

## 快乐8脚本

```bash
python3 scripts/kl8/scrape.py
python3 scripts/kl8/analyze.py
```

## macOS App

```bash
cd CaipiaoPredictor
swift run
Scripts/package_app.sh
open ../build/Caipiao\ Predictor.app
```

脚本只依赖 Python 标准库。

## 模型说明

模型分数由四类历史特征组合：

- 全历史频率
- 近 100 期频率
- 近 30 期频率
- 当前遗漏期数

回测时，每期开奖前只使用此前历史生成候选号码，再与实际开奖号比较，并和随机选号基线对照。若模型长期平均命中没有明显超过随机基线，应按“无可利用稳定优势”解释。

## 玩法分类

快乐8从 1-80 中开出 20 个号码，投注分为选一至选十。脚本用超几何分布计算各玩法命中概率：

```text
P(命中 h 个) = C(投注个数, h) * C(80 - 投注个数, 20 - h) / C(80, 20)
```

选九、选十含浮动奖，固定奖期望不会把浮动头奖当作确定收益。
