# teamsmith 0.4.8 发布记录

2026-11-24：用户此前明确授权发布新版，并选择 A 接受本版组合产品验证。`REL-0.4.8.md` 记录实际运行与证据边界：发布自检 217/0/3，安装及本地标签核对通过，唯一剩余提醒场景 V190 1/0；V174 原全量失败记录不变，不称最终版全量通过。

已发布源码：公开 `main` 从 `fdd3247a` 前移至冻结 `c34e1468ea2ab76bdff9cd2bbef0db650604d151`。`v0.4.8` 标签对象 `47732b3f1db898dac75cbb7ffe15d3c8ccdab5ab`、解引用为同一提交。公开 `dev` 保留后来追加的验证记录。干跑和实际推送均仅一条主分支和本版一个标签，原生远端回读已核对，未推其它标签。未升级任何项目。

npm 已暂存 `teamsmith@0.4.8`、tag `latest`、public，退出 0，编号 `fd3cd9fc-344c-472a-b682-b404309fca06`。实际提交的就是本地标签逐文件相同、已实际安装的唯一原始 tarball（287 个文件，SHA-256 `cbd40e453c13d9a802ea126fcf1cf08c1e55a4e2bad384e36f037cfd508c2198`）；服务回执 SHA-1 `c58a0ba7ef9ca897b725d279efe5a5e3df09ff63` 与原件一致，未重打包。正式 `latest` 实查仍为 0.4.7，等待用户在 npm 网页批准，随后核对版本和下载包。

GitHub 公开检查 [45318204605](https://github.com/Track07-cda/teamsmith/actions/runs/45318204605) 已在 `main` 的相同提交真实触发，初读 `in_progress`，尚无通过结论。