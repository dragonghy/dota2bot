# Workshop 发布手册(beta 起用)

> 第一版:2026-09-13,`beta-20260913` = main `4b789a70`(稳定锚点 stable-v9)。
> **已发布 2026-09-13:创意工坊物品 id **(https://steamcommunity.com/sharedfiles/filedetails/?id=3801134119),
> owner 经路线 B(steamcmd, macOS)上传成功,当前私有可见;git tag  = main 。
>
> 主会话打包;**上传这一步必须由 owner 在装有 Dota 2 的机器上用自己的 Steam 账号完成**
> (需要 Steam 登录 + Steam Guard,沙盒无法代劳)。

## 0. 先纠一个词

Steam **社区市场(Community Market)** 只交易物品,放不了脚本。Bot 脚本走
**Steam 创意工坊(Workshop)→ Dota 2 → Bot Scripts**。OHA 本身就是这么发的
(它的物品 id 3801134119)。

## 1. 发布包是什么

- 内容 = 仓库 `bots/` 的**全部 Lua**(275 个文件,~8MB;zip 1.7MB),**根目录直接是
  `hero_selection.lua` / `BotLib/` / `FunLib/` …**,不带 `bots/` 外壳——创意工坊物品
  的内容根就是 vscripts/bots 的内容(OHA 的安装脚本把 `workshop/content/570/<id>`
  软链到 `vscripts/bots` 即为证)。
- **排除**:`Install-to-vscript/`(上游安装脚本,指向 OHA 的物品 id)、所有
  `README.md`、`Customize/soak_side.lua`(gitignored,本来就不存在)。
- **gate 全关是验证过的**:没有 `soak_side.lua` 时 `J.IsSoakCandidate` 对任何 id 返回
  false ⇒ 发布包里跑的就是"稳定版"(所有 promote 过的默认行为),测试集里的 id 全暗。
- 打包前门:`luacheck bots game` 0 警告 + `lua5.1 tests/test_smoke_load.lua` 0 错。

打包命令(主会话或任何会话可复现):
```bash
V=beta-$(date -u +%Y%m%d)-stable-vN
mkdir -p /tmp/pkg && cp -r bots/. /tmp/pkg/ \
  && rm -rf /tmp/pkg/Install-to-vscript /tmp/pkg/Customize/soak_side.lua \
  && find /tmp/pkg -name README.md -delete \
  && (cd /tmp/pkg && zip -qr ../dota2bot-$V.zip .)
```

## 2. 自己先用(不用发布,2 分钟)

1. 解压 zip 到 `<Steam>/steamapps/common/dota 2 beta/game/dota/scripts/vscripts/bots/`
   (解压后该目录下直接是 `hero_selection.lua`;如果目录不存在就新建 `bots`)。
2. Dota 2 → 创建房间 → 服务器地点 **本地主机 (Local Host)** → 模式 **Turbo**。
3. 机器人脚本选 **Local Dev Script(本地开发脚本)**,填满机器人,开始。
4. 改代码后下一局自动重读,不用重启游戏。

## 3. 发布到创意工坊(owner 操作)

**路线 A(GUI,可靠)**:Steam 库 → 工具 → 安装 **Dota 2 Workshop Tools**(免费 DLC)。
启动后用它的创意工坊发布器(Workshop Manager / Publish):新建物品,类型 **Bot Script**,
内容文件夹选解压后的包目录,预览图选 `preview.jpg`(512×512),标题/描述从
`workshop_description.txt` 粘贴(支持 Steam BBCode),可见性先选 **私有/仅好友**
(自己先玩两局确认没问题再改公开)。
⚠️ 按钮名以你屏幕上看到的为准——官方 wiki 本次被反爬挡住没法逐字核对;找不到入口就把
界面截图给主会话。

**路线 B(命令行,一条命令,未在 Dota 2 上验证)**:SteamCMD 的 `workshop_build_item`。
把包解压到 `C:\dota2bot-beta\content`,`preview.jpg` 放 `C:\dota2bot-beta\`,
用仓库随附的 `dota2bot_workshop.vdf`(appid 570,visibility 2=私有),然后:
```
steamcmd +login <你的Steam用户名> +workshop_build_item C:\dota2bot-beta\dota2bot_workshop.vdf +quit
```
首次会要 Steam Guard 码。成功后 vdf 里的 `publishedfileid` 会被写成新物品 id;
以后更新版本用同一个 vdf(改 changenote)再跑一遍即可。
若 Dota 2 拒绝非 Workshop Tools 上传的 Bot Script 物品,退回路线 A。

## 4. 发布后

- 把新物品 id 写回本文件与 `bots/Install-to-vscript/README.md`(替换 3801134119)。
- 在房间设置里选择该物品即可(Valve 服务器房间也能用,不限本地主机)。
- 打 git tag `beta-YYYYMMDD` 对应 main commit,便于回溯"用户玩到的是哪棵树"。
- 收集反馈:issue 链接已在描述里;#322(脚本自动上报对局)落地后可自动收对局 id。

## 5. 发布前检查清单

- [ ] main 上 `luacheck bots game` 0 警告、smoke 0 错
- [ ] 包根目录是 `hero_selection.lua`(不是 `bots/hero_selection.lua`)
- [ ] 包内没有 `soak_side.lua`、没有 `.bat/.sh/.md`
- [ ] 描述里的版本号 = 包名里的版本号 = main commit
- [ ] 先私有可见,自己打 2 局 Turbo 确认 bot 名字/选人/行为正常,再公开
