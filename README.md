## 构建一个可证明公平性的彩票智能合约

## 思路

1.进入合约并且参与彩票（设置彩票进场价格）
2.选取获胜者 -> chainlinkVRF 
3.获胜者将获得彩票合约中全部奖金 
4.并且实现合约自动部署自动更新数据 -> chainlinkAUTOmation

## 功能实现

1.chainlinkVRF -> 实现公平性选取玩家
2.chainlinkAUTOmation -> 来实现合约自动化重新部署重开彩票

## 测试合约

1. 带有部署脚本和自动抓取最近部署合约的工具来进行轻松测试以及交互
2. 使合约可以在任何你想在的测试网上进行部署测试代码 
