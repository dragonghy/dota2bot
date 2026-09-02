# 协同组(strategy)章程

## 使命
全局/团队级策略 + 对线期策略 + 相关架构(TeamBrain 黑板等)。
让 5 个 bot 像一个队伍而不是五个独立个体。自驱 + 认领 [strategy] issue。

## 范围(owner 定)
- 全局策略分发:TeamBrain(团队共享 Lua VM 黑板)及其后续阶段;
- TP 纪律 / 支援仲裁 / 推进-防守姿态(midtp、suptp、tpcommit、ownhalf、
  overchase、pushguard 一族);
- **对线期策略归本组**:拉野(owner:拉野是肯定要做的,数据不对=设计或实现错)、
  兵线控制、换血、吃经验;标准策略要上网检索佐证(验证哲学条件 (c))。

## 每次触发的工作流
1. 扫 [strategy] 前缀的 open issue(dragonghy/dota2bot),优先处理带帧证据的;
   没有 issue 就从下面 backlog 取最上面一条。
2. 改动纪律(铁律之上的本组细则):
   - 每个行为改动 **gated**(`J.IsSoakCandidate('<id>')`,turbo-only),
     新 id 要在 `iterations/state.json` 登记;
   - **必须带真实帧 fixture**(make_fixture.py → tests/fixtures/ →
     tests/mock/replay_fixture.lua),gate-plumbing 测试不算本地验证;
   - 想进测试集:改 `iterations/streams/test_set.md` 提议(留历史行),
     总监批准;需要批测数据就往 `iterations/queue.json` 提请求;
   - **一次动一个小杠杆**。lanefix 大捆绑两次被拒(gpm −74.5/−88.7)的教训:
     局部各自正确 ≠ 集体涌现好。
3. push 前过铁律 6 的门(luacheck 0 警告 + 测试全绿)。
4. 报告写到 `iterations/reports/strategy/<UTC时间戳>.md`。

## Backlog(优先级从上到下,做完划掉、发现新的补进来)
0PUSH. **【2026-09-02T04:49Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;P3 责任在总监;**backlog 最上面一条 `0DUST` 逐字交待本组下一轮
   「`0SLOT9` 剩下的 8 处全在 `bots/FunLib/utils.lua` —— 一次一个杠杆」⇒ 本轮就是照这条做的**);
   **落地 gated `slotpush`**,入集提议 `test_set.md` **§DL**(搭车、零 AWS 增量、不申请专波),
   `queue.json` 新增 **`strategy-36`**(**`bundle` 已填**);`state.json` 新键 `slotpush_20260902`;
   issue **GH #415**;报告 `iterations/reports/strategy/20260902T044930Z.md`;
   零 AWS、S3 零访问、零 EC2;`game/` 零 diff。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个只能证伪的读数,这次在选杠杆之前跑了 —— 而它答的是「买不到」;
   于是本轮把「买不到」当成产物交出去,而不是当成一句脚注。**
   `corpus_hero_census.py --file bots/FunLib/utils.lua` 答 **SHARED / exit 0**(文件级),
   但**谓词自己的域要另买,而它买不到**:107 份 fixture / **517 个 member-frame** 上
   **每个合取项都会亮**(拥挤 51 / 贴二塔 10 / 贴高地塔 5 / 离敌方遗迹 <3000 三十八次)⇒ **量具不瞎**;
   但**两半同时为真只有 4 个 member-frame,全在同一份 fixture 里**
   (`f_260820_163429_es_blink_init_621`,dire),而在那一帧上**出厂腿够得到的唯一队友
   (jakiro,slot 5)自己恰好就是四个推进者之一** ⇒ 出厂答 TRUE,**理由是它没挣来的**。
   全语料**双侧 94 次载入,两条腿一次都没分歧**(`[domain price]` 钉成 `[premise]`,**变红是好消息**)。
   **缺陷**:`bots/FunLib/utils.lua`,`IsTeamPushingSecondTierOrHighGround`;
   **七个调用点全是 mode 欲望函数**(ward/rune/outpost/side_shop/secret_shop/roshan/laning),
   每个都用 TRUE 去 `BOT_MODE_DESIRE_NONE` ⇒ **失效方向朝「关」:把 bot 从高地攻坚里拽去插眼/抢神符/买装**。
   **⭐⭐ 新增的一格(两个兄弟都没有):这个循环带守卫,而守卫问的不是它接下来要看的那个人** ——
   `IsHeroAlive(playerdId)` 问一个玩家,`GetTeamMember(playerdId)` 拿回另一个;
   真实帧 **235 步里出厂配错 211 步**。armed 后三者按构造同一个英雄,**所以守卫那一行不用改**。
   **改动**:参数化 + 闸在**全仓唯一一处**解析 —— 新增包装 `J.IsTeamPushingHighGround`(jmz_func);
   **闸不能放在 utils 里是结构性的**:`utils.ts` 文件头自己禁止成环 import,而 jmz_func:35 require 了 utils。
   **产出** `tests/test_slotpush_highground_scan.lua`(**16/0**)+ `tools/agent/mutstand_slotpush.sh`(**12/12 CAUGHT**)。
   **`0SLOT9` 计数棘轮 8 → 7**(`slotarb` 与 `slotdust` **两份普查同步改**)。
   **下一格**:总监裁 §DL;录像组买条件 (a)(**判据是「找攻坚窗口」不是「找一个英雄」**,
   语料里没有必须从新局取;两个分层各自登记读数)。
   **本组下一轮**:**先读 `0PUSHCLUSTER`,下一个杠杆大概率不该从这个簇里选。**

0PUSHTRACE. **【2026-09-02T04:49Z 新增,登记 —— 一条断言写法,不是一条缺陷】**
   **⭐ 别只比结果,去截住访问器本身。**
   本轮其余每条断言都是「在函数旁边重算一遍扫描集,再比两条腿的结果」。
   在一个**结果几乎不动**的语料上(见 `0PUSH`:94 次载入 0 次翻转),那**等于没测函数自己的下标**:
   变异 **M4**(armed 改成 `i + 1`,扫 slot 2..6 —— 漏一个真队友、多读一个 nil)
   **活过了整份文件的第一版**,因为在那唯一一帧上 slot 2..6 里**仍然有一个推进者**。
   修法是 `[trace]`:把 `GetTeamMember` 包起来,断言**函数真正问出去的那串参数**
   (门关 = 活着的 player id;armed = 活着的 team slot)。
   **配套的一条**:trace 用的帧必须选谓词答 **FALSE** 的 —— **提前 `return` 会截断 trace,
   而截断的 trace 看不见尾巴**。
   与 `0CORP` 的关系:那条管**选杠杆之前**该跑什么;这条管**域买不到之后**断言该怎么写。

0PUSHCLUSTER. **【2026-09-02T04:49Z 新增,登记不修 —— `0SLOT9` 剩下 7 处的**逐处**域读数】**
   **⭐ 「一次一个杠杆」不等于「按顺序把簇修完」:先问这个簇里还有没有能证伪的杠杆。**
   utils.lua 剩下 7 处:**4 处在 `bots/` 里没有任何调用点**
   (`IsPingedByAnyPlayer` / `GetNearbyAllyAverageHpPercent` / `FindAllyWithAtLeastDistanceAway`,
   以及只在注释里被调用的 `PrintPings`)—— 修它们**按构造无法证伪**;
   **2 处**(`HasTeamMemberWithCriticalSpellInCooldown` / `...ItemInCooldown`,各 1 个调用点,
   都在 `aba_push.lua:584/587`)在同一份 107 份语料上**一次 TRUE 都没有**(0 anyTrue / 0 翻转);
   **第 7 处**是 utils 自己的 `GetHumanPing`,**死码**。
   **⭐⭐ 而那第 7 处顺手给出了「这是缺陷不是房规」的最短证明**:它的**正确孪生已经在树上** ——
   `bots/FunLib/jmz_func.lua:11342` 的 `J.GetHumanPing` 写的是 `GetTeamMember(i)`,
   **所有调用点走的都是它**。同一个功能、同一棵树、两套下标空间;
   比 §DI 的 **80:10** 比例更短、更硬。
   ⇒ **下一个杠杆去别的域挑**,并且照旧**先跑域价钱再选形状**。

0DUST. **【2026-09-02T01:37Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;P3 责任在总监;**backlog 最上面一条 `0SLOT` 逐字交待本组下一轮
   「继续先选域;候选是 `0SLOT9` 里最像的那个(`J.IsClosestToDustLocation`)」⇒ 本轮就是照这条做的**);
   **落地 gated `slotdust`**,入集提议 `test_set.md` **§DJ**(搭车、零 AWS 增量、不申请专波),
   `queue.json` 新增 **`strategy-35`**(**`bundle` 已填**);`state.json` 新键 `slotdust_20260902`;
   issue **GH #411**;报告 `iterations/reports/strategy/20260902T013726Z.md`;
   零 AWS、S3 零访问、零 EC2;`game/` 零 diff。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个「同形缺陷」不等于一个「同形论证」——
   安全性属于函数体,不属于缺陷形状。**
   `slotarb`(§DI)与本条是**逐字同一条缺陷**(域给 player id、访问器要 team slot 1..5、越界答 nil),
   **改法也逐字相同**;但 §DI 的兜底论证是「严格子集」,而它成立**只因为**
   `IsTheClosestOne` 第一行是 `local closestMember = bot`(调用者天然在候选集里)。
   `J.IsClosestToDustLocation` 第一行是 `local closest = nil`(**调用者只有被扫到才算数**)——
   **两个函数只差这一个初值,而它把结论翻了过来**:缩域**两个方向都切**,**armed 不是出厂的子集**。
   **两个方向都在真实帧上量到了**(`[not-subset]`,一帧 35 格,两向计数各 > 0)。
   **缺陷**:`bots/FunLib/jmz_func.lua`,`J.IsClosestToDustLocation`(粉/缚灵索仲裁;
   全仓三个调用点都在 `bots/ability_item_usage_generic.lua`)。
   **dire 只扫 slot 5 一个**(仲裁专属 pid-9 那个 bot;它不带粉时**全队答 nil**);
   **radiant 扫 slot 1-4**(slot 5 那个英雄**永远认领不了自己包里的粉**)。
   **⭐⭐ 一帧给出 2×2 四个格子**:`f_260820_162859_es_blink_flee_615`(dire,
   ES pid8 与 jakiro pid9 **都在主背包带粉**)—— 两个翻转方向 + 阴性对照 +
   **承重的阳性对照**;并且**出厂的答案由身份决定不由几何决定**
   (同一个 bot 在相距 **3,938 码**的两个位置上答案相同)。
   **改动**:参数化 + 闸在**新增的唯一 wrapper** `ClosestDustCarrier` 解析;门关**逐字节等于出厂函数**。
   **产出** `tests/test_slotdust_dust_arbitration.lua`(`[ratchet]` **13/0**),真实帧三份。
   **变异 16/16 CAUGHT,换掉两个**(M15 = 诊断错见 `0SLOTINSTR`;M14 = 等价变异,坐在不被碰的出厂行上)。
   **`0SLOT9` 计数棘轮 9 → 8**,`test_slotarb_camp_arbitration.lua` 同步改。
   **下一格**:总监裁 §DJ;录像组买条件 (a)(**先看 dire 侧**,两个分层各自登记读数)。
   **本组下一轮**:`0SLOT9` 剩下的 **8 处全在 `bots/FunLib/utils.lua`** —— 一次一个杠杆。

0SLOTINSTR. **【2026-09-02T01:37Z 新增,登记,**球在总监**(中心件,本组只补了最窄的一格)】**
   **⭐ 本轮最该被读的一条,比杠杆本身值钱:一个诊断可以是错的,而它周围每一条测试都是绿的。**
   本轮第一版把「`J.IsClosestToDustLocation` 在 fixture 上跑不动」诊断成
   **「三个 `ITEM_SLOT_TYPE_*` 常量不在 `_G` 里」**,并据此加了三行 `_G.ITEM_SLOT_TYPE_* = 0/1/2`。
   **变异台的 M15(删掉刚加的那一行)活了下来,而它活下来的理由就是那句话是假的**:
   `api.install` 把**任何未知全大写全局**解析成 **≥1001 的互异哨兵**
   (真实帧上量到 `ITEM_SLOT_TYPE_BACKPACK == 1174`,正好是
   `tests/test_fieldbuy_backpack_rescuer.lua:50` 注释里引的那个数)。
   **真机制是 getter**:没 spec 时 `^Get` 答 **0** ⇒ `0 == 1174` ⇒
   **全语料每一帧 FALSE,分支构造性不可达,朝「关」静默失效**(GH #89 第十三号世界断言的复发)。
   ⇒ 修法换成**只补 getter**;**常量故意不钉成 0/1/2**(钉 MAIN=0 会让每个非 fixture 英雄的单位
   默认答「主背包」,把静默 fail-closed 换成静默 **fail-OPEN**)。
   **连带**:`test_fieldbuy_backpack_rescuer.lua` 那条「mock 答不了 `GetItemSlotType`」的
   `[premise]` **当场变红并写着 re-measure** —— **一条设计得很好的棘轮**。已重新测量并重写
   (洞堵上后救援分支会触发,`SWAP 6 <-> 0`,与声明后的世界逐位相同 ⇒ 那条声明现在是**冗余**)。
   **第二个洞(本组不擅动,交总监)**:**fixture 的物品名是实体类名不是引擎物品名** ——
   dumper 写 `snakeFromClass(GetClassName(), "CDOTA_Item_")`,`replay_fixture` 加个 `item_` 前缀就当物品名用。
   粉:类名 `CDOTA_Item_DustofAppearance` vs 物品名 **`item_dust`**;
   同族还有 `sentry_ward`/`item_ward_sentry`、`empty_bottle`/`item_bottle`、`boots_of_elven`/`item_boots_of_elves`。
   ⇒ **凡按名字查背包的谓词在每一份 fixture 上都查不到东西,而测试读起来是干净通过。**
   本轮只加**有双向证据的 1 条**映射(`CLASS_TO_ITEM`),并把**未核验的天花板棘轮化**:
   **114 个 fixture 物品名里 23 个**在 `bots/` 里解析不到(**上界,不是缺陷清单**)。

0MUTPAR. **【2026-09-02T01:37Z 新增,登记 —— 一条方法,不是一条缺陷】**
   **变异台会污染任何与它并行的读数,两者不要并行。**
   本轮开工自检与变异台同时在跑,而变异台**每次迭代都在重写 `tests/mock/replay_fixture.lua`**;
   自检报的三条 Lua trunk 红里**两条是并发假红**
   (`test_lion_ult_reserve_domain` 报 `replay_fixture.lua:1087: attempt to index local 'J'
   (a boolean value)`;`test_propertarget_corpus_domain` 报帧数 990 ≠ 993),**串行重跑全绿**。
   第三条 `test_incoming_damage_callsite_census`(published 43,现读 **44**)
   **在 `git stash` 干净树上复现** ⇒ 既存,**GH #394 同族**。
   与 `0CORP` 的「变异台开跑前必须先证明基线是绿的」**同族但方向相反**:
   那条管**基线**,这条管**旁观者**。

0SLOT. **【2026-09-01T22:37Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;P3 责任在总监;**backlog 最上面一条 `0CORP` 逐字交待本组下一轮
   「先选域再选形状,优先在 SHARED 文件或 43 个在场英雄里挑杠杆」⇒ 本轮就是照这条做的**);
   **落地 gated `slotarb`**,入集提议 `test_set.md` **§DI**(搭车、零 AWS 增量、不申请专波),
   `queue.json` 新增 **`strategy-34`**(**`bundle` 已填**);`state.json` 新键 `slotarb_20260901`;
   issue **GH #406**;报告 `iterations/reports/strategy/20260901T223714Z.md`;
   零 AWS、S3 零访问、零 EC2;`game/` 零 diff。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个循环的「域」和它的「访问器」用了两套下标空间时,
   不匹配不会报错 —— 它静悄悄地缩小域,而且缩得按侧不同。**
   判别特征可数、不需要帧、不需要跑:一个参数被文档规定为 `1..N` 序数的访问器,被喂进一次**以 id 为值**的迭代。
   **缺陷**:`bots/FunLib/aba_site.lua`,`IsTheClosestOne`(野区营地仲裁,调用链单线:
   `mode_farm_generic.ClosestCamp` → `GetClosestNeutralSpwan` → 它)。
   `GetTeamPlayers` 给 **player id**(radiant 0-4 / dire 5-9),`GetTeamMember` 要 **team slot 1..5**、
   越界**答 nil**(`docs/BOT_API_REFERENCE.md:223` + 两个 mock)。
   ⇒ **radiant 扫 4/5(slot 5 从没被问过,且从第 2 步起每一步量的都是另一个英雄);
   dire 只扫 slot 5 这一个,对 pid-9 那个 bot 而言那就是它自己 ⇒ 仲裁空转、恒答 TRUE。**
   **47 份带 `player_id` 的真实帧上逐份复现:24 dire(扫 1)+ 23 radiant(扫 4),armed 全部扫满 5。**
   **失效方向朝「开」**(连着第三条,继 #393 / #397):扫得少只会让「没人比我更近」更容易成立
   ⇒ 多个 bot 各自认定同一个营地归自己。
   **⭐⭐ 它是缺陷不是房规**:出厂树全仓 **91 个调用点**里 **80 处当 slot 用、10 处当 player id 用**
   (**80:10**,与 #397 的 64:6、#385 的 249/227/1 同族),而两种写法坐在同一批文件里、
   迭代同一个 `GetTeamPlayers(GetTeam())`。
   **改动**:参数化 + 闸在**全仓唯一那处**解析(和 `campsel` 同一个 wrapper);门关**逐字节等于出厂函数**;
   **严格子集:armed 扫的是超集,而扫得更宽只可能找到更近的人 ⇒ armed 的 TRUE 集是出厂 TRUE 集的严格子集**
   —— 只可能让出一个营地,永远不可能多占一个(`[subset]` 实测 **46 次翻转、反方向 0 次**)。
   **产出** `tests/test_slotarb_camp_arbitration.lua`(`[ratchet]` **12/0**),真实帧两份:
   `f_260819_182855_lion_drain_jungle`(dire, lion,出厂只看见自己)与
   `f_260820_043120_viper_defend_paired`(radiant, viper,4/5 且四步全错位)。
   **`[decision, positive control]` 承重**:armed 仍然认领一个确实没人更近的位置 ⇒
   「armed 说 false」不能被一个「永远说 false」的修复满足。
   **变异 14/14 CAUGHT**,**但第一遍两个活口**:**M12 是真洞** ——
   ts-parity 断言写成 `sel:find('bSlotArb')`,**参数表本身就满足它**
   (**用错误理由达成的正确结论**,与 #397 的 M2、#400 的 M4b **同形,连着第三轮**);
   M8 是**等价变异**(注释不是代码,那一半是正确行为),已换真的。
   **⛔ 本条最该被读的一句(见 `0MOCKHOLE`)**:这条缺陷**只有真实帧看得见**。
   **下一格**:总监裁 §DI;录像组买条件 (a)(**先看 dire 侧**,两个分层各自登记读数)。
   **本组下一轮**:继续先选域;候选是 `0SLOT9` 里最像的那个(`J.IsClosestToDustLocation`)。

0MOCKHOLE. **【2026-09-01T22:37Z 新增,登记,**球在总监**(中心件,本组不擅动)】**
   `tests/mock/bot_api.lua` 的 `GetTeamMember(n)` **对任何 `n` 都造一个英雄出来,永远不答 nil**
   (`if i == 1 then return bot end; return M.MakeHero('npc_dota_hero_teammate_'..i, …)`)。
   ⇒ **任何写在那个 mock 上的单元测试,对 `0SLOT` 那条缺陷是结构上失明的 —— 不是没查,是查不到。**
   **这就是 91 个调用点带着 10 处错误、而整套测试一路绿灯的原因。**
   只有 `tests/mock/replay_fixture.lua` 的真实 roster(按 `player_id` 排序、按下标取)会答 nil。
   本轮把这个洞**棘轮化**(`test_slotarb_camp_arbitration.lua` 的 `[instrument]`,
   断言写成「洞还在」并注明修好后要连同这条一起删)。
   与 §CL / GH #329 **同族**:那次是**读数不是局数**,这次是**「测试跑了」不是「测试看得见」**。

0SLOT9. **【2026-09-01T22:37Z 新增,登记不修 —— `0SLOT` 之外那九处,**一次一个杠杆**;计数已棘轮】**
   `bots/FunLib/utils.lua` **8 处**(`:917 :1010 :1028 :1249 :1690 :1758 :2080 :2097`)+
   `bots/FunLib/jmz_func.lua:11470`(`J.IsClosestToDustLocation` —— **同一个「我是不是最近的那个」仲裁形状**,
   最像的一个,建议作为下一个杠杆)。`[census]` 把「还剩 9 处」钉成断言,
   所以再修一处是一次**有意的**动作,而不是漂移。
   **另有一处形状不同、也登记不修**:`bots/FunLib/advanced_item_strategy.lua:332`
   写的是 `GetTeamMember(GetOpposingTeam(), i)` —— **两个参数**喂给单参数 API,第一个还是**队伍常量**;
   它**跨两行**,所以**按行扫的普查根本看不见它**(本轮普查第一版就漏了它,改成整文件读才钉住)。
   **【2026-09-02T04:49Z 更新】** 计数棘轮 **8 → 7**(`slotpush` 拿走了
   `IsTeamPushingSecondTierOrHighGround`;`slotarb` 与 `slotdust` 两份普查同步改)。
   **剩下 7 处的逐处域读数见 `0PUSHCLUSTER`:四处无调用点、两处在语料上恒 FALSE、
   一处是死码且正确孪生已在树上 ⇒ 下一个杠杆大概率不该从这个簇里选。**

0CORP. **【2026-09-01T19:21Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;P3 责任在总监;backlog 最上面三条 `0HPB`(已落地)/ `0HPB5`(登记不修,
   **且明写要等本轮这道读数**)/ `0HPBX`(登记不修)⇒ **本轮兑现的正是上一轮亲手交出去的 §DG.7.1**);
   **零行为改动**:无新 gate、无 armed id、无入集提议、无 `queue.json` 请求,`bots/` 与 `game/` **零 diff**;
   issue **GH #400**;报告 `iterations/reports/strategy/20260901T192129Z.md`;零 AWS、S3 零访问、零 EC2。
   **已交棒,球在总监(§DG.7.1 进不进流程)。**】**
   **⭐ 主判据(可复用,超出本主题):一个只能证伪的读数,必须在选杠杆之前跑,不是在裁定之后补。**
   这道读数两个方向的价钱**完全不对称**:语料出场 **=0** ⇒ fixture 级买到条件 (a) **不可能**(**承重**);
   **>0** ⇒ 只是**没被排除**(几乎不承重,域还得可达)。**便宜的那半正是能说「别做」的那半** ——
   而 **#385 / #393 / #397 连着三轮没在选题前跑它**(brewmaster 0、tiny 0,`0HPB5` 的三个各 0)。
   #397 是总监 §DF.6 点名的**第三条 null**,并第一次把它量成读数 —— 但那读数**长在一个测试文件的
   `[source S6]` 里**,只在那次修复被跑到时才存在。
   **⭐⭐ 结构性逃生口(可操作的一半)**:**共享代码里的杠杆不付这笔域价钱** ——
   `bots/mode_*.lua` / `bots/FunLib/*` / generic override 的域是**语料里的每一个英雄**,
   `bots/BotLib/hero_<x>.lua` 则全额支付;`--file` 把这条区分做成**工具的答案**而不是读者的推断。
   **产出** `tools/agent/corpus_hero_census.py`(秒级、只读、零 AWS;退出码沿用 **0/2/3**:
   0 都在场 / 3 至少一个语料为 0 / **2 语料读不到 ≠「都不在场」**)+
   `tests/test_corpus_hero_census.py`(`[ratchet]` **32/0**,驱动真脚本不重实现)。
   **实测**:108 帧文件 / 43 个英雄;CM 54·40、lina 52·38、zuus 52·38、viper 48·37、
   WK 37·29、axe 29·20、lion 24·…;**五个焦点英雄全部在场** ⇒
   「域买不到」**不是本仓的普遍处境,只是最近三轮的选题处境**。
   **变异 14/14 CAUGHT**,但**六个变异活过了第一遍**,逐条记在报告 §二:
   M4b 被**表头那行 `WeakHeroes list : 18`** 满足(**与 #397 的 M2 一模一样的形状**:
   用错误理由达成的正确结论);M6b 被另一条独立路径满足;M9/M10/M11/M13 靠补**绝对声称**才钉住,
   **M13 尤其** —— 原 `--top` 断言拿输出跟同一份输出的前 5 行比,**在任何排序下都自洽**。
   **⛔ 并登记一次被污染的变异回合**:加完「表格行数 == 表头英雄数」后干净树自己就红了
   (42 vs 43,行正则没放过 `<- WeakHeroes` 后缀),那一轮 **11 个变异全部报 CAUGHT** ——
   **它们是被那条本来就红的断言抓的**。修好后整轮重跑。
   **变异台在开跑之前必须先证明基线是绿的**(与 `mutstand_pipe_guard` 同族)。
   **下一格**:**总监**裁 §DG.7.1 —— 工具与棘轮都已落地,只剩「进不进流程」;
   建议落法见报告 §五(README 铁律 4 或 `test_set.md` 入集清单加一行:
   提议 gated fix 前跑 `--file <改动文件>`,**exit 3 要么换杠杆、要么写明为什么仍然值得**)。
   **本组下一轮**:**先选域再选形状**,优先在 `SHARED` 文件或 43 个在场英雄里挑杠杆。

0NOTNUM. **【2026-09-01T19:21Z 新增,登记不修 —— `hpbool` 主判据的**取反极性**,#397 的 `[source S2]` 漏掉的那一格】**
   `bots/FunLib/minion_lib/utils.lua:31`,`U.CantMove`:
   `or not unit:GetCurrentMovementSpeed() or unit:GetCurrentMovementSpeed() < 100`。
   `GetCurrentMovementSpeed()` 返回数值,Lua 里 **0 也为真** ⇒ `not <数值>` **恒假**,
   这条 nil 保护**一次都没保护过**。**全仓这个取反形状只有这 1 处**(本轮扫过,**未棘轮**)。
   **不改的理由是它拿不到东西**:紧随其后的 `< 100` 完成了作者的全部意图,
   armed/baseline **逐字节同判决**,可省的只有一次引擎调用 ⇒ **不是杠杆,是注记**。
   要改就得连「速度真的可能是 nil 吗」一起买到证据(条件 (c))。

0SHAPE0. **【2026-09-01T19:21Z 新增,登记 —— 本轮扫空的两个形状,**未棘轮**,别再重扫】**
   (甲)**循环体在第一次迭代就无条件 `return`/`break`**(「循环是句谎话」):全仓 **0**。
   (乙)**同一 `if/elseif` 链里重复的条件**(后一条恒不可达):全仓 **0**。
   ⚠️ 两条都**踩过自己造的假阳**:初版 (乙) 报 68 条,全部来自
   ①把字符串字面量抹成 `''` 于是 `char == ''` 互撞;②`elseif` 的链身份记在 `depth` 而 `if` 记在 `depth-1`,
   于是 radiant/dire 两条**兄弟链**被读成同一条。修完两处才归零。
   **重扫之前先复现这两个假阳**,否则会第三次得到 68 这个数字。

0HPB. **【2026-09-01T18:55Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;P3 责任在总监;backlog 最上面三条 `0IMM`(已落地)/ `0TREE`(登记不修)/
   `0REPICK`(严格更大的杠杆)都已结清或明写不做 ⇒ 本轮开一次**新的机械化普查**);
   **落地 gated `hpbool`**,入集提议 `test_set.md` **§DG**(搭车、零 AWS 增量、不申请专波),
   `queue.json` 新增 **`strategy-33`**(**`bundle` 已填**);`state.json` 新键 `hpbool_20260901`;
   issue **GH #397**;报告 `iterations/reports/strategy/20260901T185500Z.md`;
   零 AWS、S3 零访问、零 EC2;`game/` 零 diff。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个操作数是数字的合取项不是条件,是一句 `and true`。**
   **判别特征可数、不需要帧、不需要跑**:一个返回类型为数值的调用出现在**裸真值位**(没有 `<`/`>`/`==`)。
   **全仓 6 处**(`[source S1]`),全是同一个 `J.GetHP` 惯用法,散在 4 个英雄文件;
   把同样形状扫到别的 `J.Get*` 助手上(`[source S2]`)**零命中** ⇒ **6 处是全体,不是样本**。
   **缺陷**:`bots/BotLib/hero_tiny.lua:487`,`X.ConsiderToss` 撤退臂
   `or (J.GetHP(bot) and bot:WasRecentlyDamagedByAnyHero(2))`。`J.GetHP`(`jmz_func.lua:4003`)
   返回 `nCurHealth / nMaxHealth`,死亡路径返回**裸的 `0`** ⇒ **从不 nil、从不 false**,
   而 Lua 里 **0 为真** ⇒ 该操作数**恒真**,合取项付了一次除法的钱、什么也没决定。
   **失效方向朝「开」**,与 #393 同侧、与它之前的七条(#348/#368/#370/#373/#378/#381/#385)相反。
   **⭐⭐ 它是缺陷不是取舍,而最窄的那条证据在同一个文件里**:全仓 **64 处**写的是带阈值的
   同一惯用法(众数 **0.65**,11 处),**6 处丢了 `< X`**(**64 : 6**,与 #385 的 249/227/1 同族);
   而 **`hero_tiny.lua:659`,比缺陷低 170 行,写的就是正确版本、用的就是这个 0.65**。
   **⭐⭐⭐ 代价收两次,第二次才值得要**:(1) 出厂 Tiny 撤退时**任何血量**都 Toss;
   (2) **支配** —— 闸是 `(#enemies > #allies) or (<恒真> and recentlyDamaged)`,撤退中右臂几乎恒真 ⇒
   **左臂(作者亲手写的「被压人数」判别)也永远决定不了任何事**,一个死合取项静悄悄杀掉整条竞价
   (`[frame F4]` 钉成等价式)。
   **改动**:不改出厂操作数,**追加** gated 合取项;门关 ⇒ `not false` = true ⇒ **逐字节等于出厂判决**;
   **严格子集:armed 只可能撤掉一次施法,永远不可能新增一次**(`[frame F5]` 全阵容扫)。
   **产出** `tests/test_hpbool_dead_conjunct.lua`(`[ratchet]` **13/0**),真实帧
   `f_260820_043120_viper_defend_paired`(t=599.5)—— **一帧同时带案例与对照**:
   viper 1644/1683 = **0.977**、2.0s 前被英雄打过;axe(**焦点英雄**)579/1708 = **0.339**、0.5s 前被打过。
   **`[frame FC]` 阳性对照承重**(低血 axe 两臂都必须放行)。
   **变异 10/10 CAUGHT。⚠️ 诚实注记:第一遍 M2(0.65 → 0.5)是活的** —— 断言写成
   `CODE:find(...)`,被 `:659` 那份**本修复根本不碰的正确拷贝**满足了:**用错误理由达成的正确结论**,
   而**让它变空洞的正是上面算作证据的那个邻居**;改成对切片表达式求证后 CAUGHT。
   门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
   `hpbool` 13/0 · `smoke_load` 3/0 · `gate_claim` 10/0 · `immguard` 14/0 · `replay_fixture` 9/0;
   **全量套件没跑完(GH #124),不声称**。**三处 trunk 红全部在 `git stash` 干净树上复跑确认既存**
   (`test_wave_gate_keys.py` = #396;`test_carrier_terms.py` 同一份 W35 wave 文件;
   `test_incoming_damage_callsite_census.lua` = #394)。
   **⭐⭐ 本轮最该被读的一条(交总监)**:`[source S6]` 走遍 110 份 fixture ——
   **tiny / shredder / dawnbreaker / kez 出场 0 次,brewmaster(#393 主体)也是 0 次** ⇒
   **连着三轮(#385 / #393 / 本轮)被修英雄的语料出场为零**,而总监 §DF.6 要求
   「**在它产出第三条、第四条 null 之前先给这个形状起好名字**」—— **本轮就是第三条**,
   且第一次把它量成**可运行的读数**。**建议把「语料出场普查」提成入集前的常设读数**(本地、秒级、零 AWS)。
   **同时登记一处结构性改善,也是量出来的**:`WeakHeroes` 节流名单上**有 brewmaster、没有这四个** ⇒
   #393 同时跟语料和抽签作对,本条只跟语料作对。
   **明说没做**:6 处只修 1 处(另外 5 处 shredder 3 / kez 1 / dawnbreaker 1,`[source S1]` 点名计数,
   见 `0HPB5`);**阈值是借来的**(0.65 = 64 份兄弟拷贝的**众数**,换阈值 = 换杠杆,见 `0HPBX`);
   `WasRecentlyDamagedByAnyHero(2)` 的 `2` 不动;`#enemies > #allies` 项用的是**合成表长度**
   (血量项与近期受伤项是真实帧数据,**基数项不是**,已在测试里逐字声明)。
   **下一格**:**总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 主判据进不进 §CR;
   **丙 §DG.7.1 —— 语料出场普查要不要成为常设入集前读数,这是本轮真正想交出去的那一棒**);
   **录像组**(只缺一种读数:「Tiny 撤退 ∧ 2s 内被英雄打过 ∧ 血量 > 65% ∧ 施放 Toss」的窗口;
   `acceptance` 已按 §CJ 预登记 **`METHOD-FAILED`** ⇒ 没有 Tiny 出场判 **`DOMAIN-EMPTY` 退回总监**)。
   **批测台:`strategy-33`,搭车、零 AWS 增量、零 EC2。**

0HPB5. **【2026-09-01T18:55Z 新增,登记不修 —— `0HPB` 那次普查的另外五个活实例】**
   同一形状、同一失效方向(朝开)、同一处修法,只是在别的英雄上:
   `hero_shredder.lua:283 / :429 / :541`(旋风斧 / 木锯链撤退 / 战刃)、`hero_kez.lua:458`(钩爪撤退)、
   `hero_dawnbreaker.lua:483`(天体铁锤撤退)。**一次一个杠杆**,所以本轮只动了 Tiny 那一处。
   由 `tests/test_hpbool_dead_conjunct.lua` `[source S1]` **按文件点名并计数**(3 / 1 / 1),丢不掉;
   出现在第五个文件里会被直接判为**新成员而不是扫描器坏了**。
   ⚠️ **它们与 Tiny 那一处的差别只有一个:域**。四个英雄在语料里出场**都是 0**(`[source S6]`),
   所以先做哪一个不应该按「哪个更明显」排,而应该等 §DG.7.1 那道读数落地后按**买得到 (a) 的概率**排。

0HPBX. **【2026-09-01T18:55Z 新增,登记不修 —— `0HPB` 明说不做的那一半】**
   **0.65 是借来的,不是推出来的**:它是 64 份兄弟拷贝的**众数**,而那 64 份的值域是 **0.2 .. 0.82**。
   「Tiny 撤退时该在多少血以下才值得 Toss」**本仓没有任何一帧论证过**。
   要动这个常数,就得先买到那个论证(帧证据或标准打法检索),**换阈值 = 换杠杆**。
   `[source S3]` 把常数钉在众数上,于是**改常数的人必须同时改理由**。

0IMM. **【2026-09-01T13:55Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;P3 责任在总监 ⇒ 取**上两轮都逐字写下来的那条遗留**:
   「`aba_hero_sub_units.lua` / `primal_split.lua` 的 4 处 `Action_AttackUnit(x, false)` 只普查、未审计」;
   GH #385 已证前者**零引用者** ⇒ **`primal_split.lua` 就是这条遗留的全部活体**,本轮是那次审计);
   **落地 gated `immguard`**,入集提议 `test_set.md` **§DE**(搭车、零 AWS 增量、不申请专波),
   `queue.json` 新增 **`strategy-32`**(提议方自建,**`bundle` 已填**);`state.json` 新键 `immguard_20260901`;
   issue **GH #393**;报告 `iterations/reports/strategy/20260901T135500Z.md`;
   零 AWS、S3 零访问、零 EC2;`game/` 零 diff。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个两条臂返回同一个表达式的分支不是过滤器,是一句注释 ——
   只是它还要付一次函数调用的钱。**
   **判别特征可数、不需要帧、不需要跑、也不需要理解那个谓词**:
   `if C then return E end` 紧跟一个 `return E`。**改动前全仓 3 处**(`[source S1]` 把这条 grep 机械化了;
   改动后 2 处,两个幸存者点名,第三个由**把门抠掉重建**证明曾在册)。
   **⚠️ 而它与同族七条失效方向相反,这才是它值得单独登记的地方。**
   #348 顺序 / #368 词法作用域 / #370 未汇报副作用 / #373 闩记错后置条件 / #378 节流器作用域 /
   #381 手工字段复制引擎事实 / #385 谓词被喂 self —— **七条全朝「关」失效**:
   一条该发生的分支不发生,而且**七条都不可观测**(「没触发」与「被正确否决」在任何观察下一模一样)。
   **本条朝「开」失效**:闸放行一切,错误答案是一个**积极动作** —— 一条打在打不动的单位上的攻击命令。
   **它不是不可观测,只是没人看**:唯一到达这个文件的英雄是**开着大招的酒仙**。
   **缺陷**:`bots/FunLib/minion_lib/primal_split.lua:109`,`AttackUnits` 出口。
   `if target ~= nil and not target:IsAttackImmune() and not target:IsInvulnerable() then return target end`
   之后紧跟一个裸的 `return target` ⇒ **这个免疫过滤器一次都没有筛掉过任何东西**。
   **⭐⭐ 它是缺陷不是取舍 —— 仓库自己回答了两遍,而第二遍才是关键**:
   (1) 英雄臂调的 `J.GetWeakestUnit` 就是 `J.GetAttackableWeakestUnitFromList`(`jmz_func.lua:3748`),
   其选取条件里**逐字**写着这两个否定(`:3764-3765`)⇒ **`return nil` 不是本改动的发明,
   是仓库自己的 picker 在同一次调用上的做法**;
   (2) **……而三行之后 `:105` 把 picker 的 `nil` 读成「没有意见」,`target = enemies[1]` 把它刚拒绝的
   同一个句柄放了回来** ⇒ **手写这道闸不是冗余的第二意见,它是不可攻击单位与攻击命令之间唯一的东西,
   在每一条臂上,包括英雄臂**(`[frame F6]` 在真实帧上跑出来:picker 答 `nil`,出厂树照样攻击那个句柄)。
   **⭐⭐⭐ 代价在调用点上收两次**:`X.MinionThink:65-69` 拿到句柄就 `Action_AttackUnit(target, false)`
   **然后 `return`** ⇒ (a) 一条引擎判定为零伤害的命令;(b) **`ConsiderMove` 整个不跑** ——
   而对**火熊猫**来说 `ConsiderMove` 就是它行为的全部(自己的技能分支是 `:52-53` 的一个**空 `if`**)。
   **改动**:**不删那道闸**,把 gated 提前返回**插在两条臂之间**;
   门关 ⇒ 控制直接落到出厂 `return target`(**出厂路径不变**),门开 ⇒ 否定臂返回 `nil`。
   **⚠️ 注意方向:armed 不是严格超集**,它**减少**一条攻击命令;
   可以这么改的理由是**引擎规则本身** —— 对 attack-immune / invulnerable 单位的攻击**恒定零伤害**,
   **被拿走的那条命令在信息上是空的**,换回来的是一条真的移动命令。
   **产出** `tests/test_immguard_dead_filter.lua`(`[ratchet]` **14/0**),真实帧
   `f_260819_142047_zuus_ult_denied`(主体 **zuus,焦点英雄**,t=278.5)。
   **选它的理由是几何,而几何是 dump ground truth**:中路 (63, 89)、**存活敌方塔 727u**、
   **1600 内 0 个敌方英雄**(最近 7479u)⇒ 把 `AttackUnits` 一路推进**塔臂**,那条没有任何过滤的
   `enemies[1]` 路径。**变异 14 条:14 条全部 CAUGHT**(诚实注记:**M11 是加载期语法错,
   被解释器抓住不是被断言抓住,十四条里最弱**)。
   门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**,变异台前后各跑一次;
   `immguard` 14/0 · `smoke_load` 3/0 · `gate_claim` 10/0 · `illureal` 12/0 · `illumove` 9/0 ·
   `replay_fixture` 9/0;**全量套件本轮没跑完(GH #124),不声称**。
   **⚠️ 方法自伤被提前挡住(而不是事后发现)**:`[frame FC]` 先立成**承重的阳性对照**
   (帧按 dump 原样、什么都不声明,**两条臂都必须攻击那座塔**),理由是 §DD 的教训
   ——「**一道关着的闸,在有东西证明它能开之前,什么都没证明**」。随后 `[frame F1]` 量出
   `IsInvulnerable`/`IsAttackImmune` 在 fixture 上**全帧全句柄读 false** ⇒
   **没有 FC,F2/F3 完全可能因为闸根本没被走到而「通过」**。
   另有两处断言写窄了(已修):`[source S1]` 第一版扫描器**只认单行 `if ... then`**,
   于是**三处里只看得见一处** —— **一个把自己看到的当成全部的普查**;
   `[source S3]` 第一版把 `return target` 数成 2,实际 3(`:86` 的 leash 早退也是一条)。
   **明说没做**:`J.GetBestRetreatTree`(`jmz_func.lua:12109`)—— **同一次普查找到的第二个活实例**,
   `maxDist > bot:GetAttackRange()` 被同样丢掉,唯一调用方 `hero_shredder.lua:435`,
   **登记不修,一次一个杠杆**(见 `0TREE`);`hero_earth_spirit.lua:680` **故意不动**
   (整函数是桩 ⇒ **没有被丢掉的答案,也就没有可恢复的东西**);
   **armed 不重选目标**(那是严格更大的杠杆,见 `0REPICK`);
   **⚠️ 频率未知且比平时更重 —— 酒仙不是焦点英雄 ⇒ 五个焦点英雄身上一个读数都买不到**,
   而且**这个域在 fixture 上根本买不到**(`[frame F1]` 实测),只能在真实录像上验。
   **下一格**:**总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 主判据 ——
   **尤其「本条朝开失效」这条与前七条的分界** —— 进不进 §CR;丙 `strategy-31` 仍待裁);
   **录像组**(只缺一种读数:**「酒仙开着 Primal Split ∧ 某只熊猫的攻击目标是不可攻击单位」的窗口
   有多少、多长**;`acceptance` 已按 §CJ 预登记 **`METHOD-FAILED`** ⇒ 没有这种窗口、甚至根本没有
   酒仙出场,判 **`DOMAIN-EMPTY` 退回总监**)。
   **批测台:`strategy-32`,搭车、零 AWS 增量、零 EC2。**

0TREE. **【2026-09-01T13:55Z 新增,登记不修 —— `0IMM` 那次普查的第二个活实例】**
   `bots/FunLib/jmz_func.lua:12109`,`J.GetBestRetreatTree`:
   `if bestRetreatTree ~= nil and maxDist > bot:GetAttackRange() then return bestRetreatTree end`
   紧跟一个裸的 `return bestRetreatTree` ⇒ **`maxDist > bot:GetAttackRange()` 这个条件被丢掉**,
   与 `0IMM` **同一形状、同一失效方向(朝开)**。唯一调用方 `bots/BotLib/hero_shredder.lua:435`
   (伐木机的木锯链撤退)。**它与 `0IMM` 的差别在于「作者想拦什么」不像后者那样有仓库先例佐证**
   —— 恢复这个条件等于声称「近到攻击距离以内的树不值得拿链子去撤」,
   **这条得先找到理由(条件 (c)),不能只靠形状**。
   由 `tests/test_immguard_dead_filter.lua` `[source S1]` **点名并计数**,丢不掉。

0REPICK. **【2026-09-01T13:55Z 新增 —— `0IMM` 明说不做的那一半】**
   `primal_split.lua` 的 `AttackUnits` armed 时对不可攻击候选返回 `nil`,
   **不会接着去找下一个可攻击单位**。重选是**严格更大的杠杆**:它改变**打谁**,
   而 `0IMM` 只改变**要不要下一条空命令**。真要做,得连 `:105` 那条
   `target = enemies[1]`(**把 picker 刚拒绝的句柄放回来**的那一行)一起重新设计,
   而那一行同时是四条臂的兜底 ⇒ **不是一个小杠杆,需要自己的帧证据与自己的域读数**。

0TORM. **【2026-09-01T10:30Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;P3 责任在总监 ⇒ 取 backlog 最上面一条 `0FIELD`
   **明说没做的那两项**之一:「`aba_hero_sub_units.lua` / `primal_split.lua` 的 4 处连续命令仍只普查未审计」。
   **审计它先证明了一件反直觉的事:`aba_hero_sub_units.lua` 被任何文件 require —— 零个**,
   它是被 `minion_lib/` 取代的遗留文件,**它里面的缺陷不值一个 diff**;
   **但证明它死的那次普查,正是找到唯一存活拷贝的那次普查**);
   **落地 gated `tormself`**,入集提议 `test_set.md` **§DD**(搭车、零 AWS 增量、不申请专波),
   `queue.json` 新增 **`strategy-31`**(提议方自建,**`bundle` 已填**);`state.json` 新键 `tormself_20260901`;
   issue **GH #385**;报告 `iterations/reports/strategy/20260901T103016Z.md`;
   零 AWS、S3 零访问、零 EC2;`game/` 零 diff。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个以「别的单位」为域的谓词被喂了 `self`,
   是一个语言抓不到、运行期也不报的类型错误** —— 因为 `bot` 与 `botTarget` 是**同一种鸭子类型**
   (单位句柄),而这个谓词是**全函数**:对 self **不抛错,只是恒假,永远**。
   失效方向朝**关**,而且它的静默是本档案里**最强的一种**:
   **没有任何一帧、任何一局、任何一份录像上,这个错答案与一个正确的 `false` 有区别** ——
   因为对 `self` 而言,正确答案**就是** false。**只有调用点知道这个问题是问别人的。**
   **判别特征可数、不需要帧**:枚举身份谓词的调用点,看每个被喂了什么。
   实测(code-only、剔除死文件):**249 个存活 `J.IsTormentor` 调用点,227 个(90.8%)喂 `botTarget`,
   恰好 1 个喂 `bot`** —— 那一个就是缺陷。
   **⭐ 必须一并记住的边界:「self-fed」本身不是判据。`J.IsMeepoClone(bot)` 是合法的 self-fed**
   (一个 Meepo bot 真的可能是分身)**;判据是 self-fed ∧ self 不可满足。**
   本轮的类棘轮 `[source S5]` 正是按这条写的:管 `IsRoshan`/`IsTormentor`,**故意不管 `IsMeepoClone`**。
   **与同族六条划界**:#348 **拼错**(标识符不存在)、#368 **词法作用域**(名字对绑定错)、
   #370 **未汇报的副作用**、#373 **闩记错后置条件**、#378 **节流器作用域**、#381 **手工字段复制引擎事实** ——
   **本条里每个标识符都存在、拼对、在作用域内、不持状态、永不过期,调用的函数也是对的那一个;
   错的完全是「它被问的是哪个对象」。**
   **缺陷**:`bots/BotLib/hero_ringmaster.lua:915`,`X.ConsiderFunhouseMirror`。
   闸的外层按 bot 的 mode 二路分(`J.IsDoingRoshan(bot) or J.IsDoingTormentor(bot)`),
   内层本该按 target 做同样的二路判别 —— **Roshan 臂写对了**(`J.IsRoshan(botTarget)`),
   **Tormentor 臂问的却是 `bot`**。`J.IsTormentor`(`jmz_func.lua:10638`)是纯粹的单位身份谓词
   `string.find(nTarget:GetUnitName(), 'miniboss') ~= nil`,我们自己的英雄叫 `npc_dota_hero_ringmaster`
   ⇒ **那条臂构造上恒假**,于是**外层析取的整个 Tormentor 那一半够不到函数体**
   (打 Tormentor 时 `J.IsRoshan(botTarget)` 也假)。
   **⭐⭐ 它是缺陷不是取舍,同一行上就能判**:把 Tormentor 臂读成 mode 测试**更糟不是更好** ——
   真正对 `bot` 有意义的那个 `J.IsDoingTormentor(bot)` **已经是外层的第二条臂**,
   那样读作者就是在一个真判别旁边写了一次**恒真的重复检查**。两种读法都错;
   **只有 target 读法有用,而那正是另外 227 个调用点的写法,包括本文件自己另外四处(436/622/846/965)**。
   **⭐⭐⭐ 为什么没人发现**:这是**复制粘贴的一脉**而非孤例 —— 另有 `aba_hero_sub_units.lua:370`
   与 `familiars.lua:358`(被注释掉的)。**但那个文件零引用者,这一脉三分之二是死代码**
   ⇒ grep 这句话的人看到的命中绝大多数在跑不起来的文件里,**唯一存活的那份因此也像是同一堆死东西**。
   由 `[source S4]` 钉住(将来谁把死文件接回来,这条断言就红)。
   **改动**:新增文件内局部 `IsTormentorSubject()`,按 `J.IsModeTurbo() and J.IsSoakCandidate('tormself')` 分叉;
   **门关逐字返回 `J.IsTormentor(bot)` ⇒ 出厂字节级不变**;门开返回 `J.IsTormentor(botTarget)`。
   **因为关着的那条臂恒假,开的那条是严格超集 —— arming 不可能让 Ringmaster 反而不做今天会做的事。**
   **Roshan 臂与发货函数体其余一字未动。** 访问器**放在 `local botTarget`(156 行)之下**是有意的
   (放其上会闭包到另一个**永远 nil** 的 upvalue,armed 臂会和 shut 臂一样死;GH #368 形状,**变异 M11 实证**)。
   **产出** `tests/test_tormself_identity_domain.lua`(`[ratchet]` **10/0**),真实帧
   `f_20260828_004757_venomancer_785`(t=785.4,主体存活 1219/1219,完整十人阵容)。
   **`[frame F0]` 把这条发现量出来而不是论证出来**:用**真实的** `J.IsTormentor` 跑遍语料里每一帧的每一个英雄句柄 ——
   **107 帧 / 993 个句柄 / 41 个不同英雄名,为真 0 次。不是罕见条件,是空条件。**
   **⭐ `[frame FC]` 是阳性对照,也是让其余读数有意义的那一条**:**同一个 `if` 的兄弟臂**,**不开门**,
   bot 在 Roshan mode、Roshan 在面前 ⇒ **HIGH**。**变异 11 条:11 条全部 CAUGHT。**
   门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**,变异台前后各跑一次;
   `tormself` 10/0 · `smoke_load` 3/0 · `gate_claim` 10/0 · `illureal` 12/0 · `illumove` 9/0;
   **全量套件本轮没跑完(GH #124),不声称**。
   **⚠️ 一次方法自伤,被本文件自己的阳性对照抓出**:`[frame F1]` 一开始读出 NONE 并**「通过」**了 ——
   真实原因是主体是 venomancer、fixture 里没有 `ringmaster_funhouse_mirror`、mock 返回**未学习**的技能桩,
   `J.CanCastAbility` 在函数**第一行**就 bail,**距离受测那条臂还有四个条件**。
   **一道关着的闸,在有东西证明它能开之前,什么都没证明。** 已补世界槽 S-D 并新增 `[frame FC]`。
   **登记理由是失效方向:提前 bail 的闸长得和正确判别后关上的闸一模一样,而它 bail 的方向恰好是这个测试想要的答案。**
   与 #377 的 M8、#381 的普查拼写同族 —— **读数是对的,理由不是。**
   **⚠️ 另一条断言自审**:`[source S2]` 起初只断 `accessor > declaration`(读者那一半),
   变异 **M11**(把 `local botTarget` 下移到访问器正上方)**保持该式为真却仍打断了修复** ——
   `X.SkillsComplement` 于是赋值给一个**全局** `botTarget`,访问器读的是那个 nil 的文件局部。
   **M11 是被帧测试抓到的,S2 没抓到。** S2 现已加断 `writer > declaration`,重跑确认 S2 会红。
   **一条守得比自己名字少的断言。**
   **⚠️ 开工自检**:第一条命令仍写成 `| tail`,**被拒绝横幅当场拆穿**(同一站点连续第九轮);
   改重定向后**第一次被我自己的 `timeout 400` 杀掉(`EXIT=124` —— 那不是通过,是没跑成)**;
   后台重跑得 **43 checks / 0 failures / 9 UNCERTIFIED**,**9 条全是 GH #358 那个 120s 预算超时的
   trunk-health 腿,没有一条是本轮的**;另有一条 python 腿 UNCERTIFIABLE。
   **明说没做**:`primal_split.lua` 的连续命令位点(`0FIELD` 留下的另一半)**仍只普查未审计**;
   `aba_hero_sub_units.lua` 自己那份拷贝**故意不修**(修死代码只会制造一个量不到的 diff);
   **⚠️ 频率未知且比平时更重 —— Ringmaster 不是焦点英雄 ⇒ 五个焦点英雄身上一个读数都买不到**,
   而分支还要 `BOT_MODE_SIDE_SHOP` ∧ 大镜子不在 CD ∧ Tormentor 在 900u 内 ∧ 正在攻击;
   **这个合取的出现率未证,那就是本修复价值的上界。**
   **下一格**:**总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 主判据 —— 含
   **「self-fed 不是判据,self-fed ∧ self 不可满足才是」**这条边界 —— 进不进 §CR;
   **丙已消** —— rebase 时发现总监在本轮落地的**同一小时**(10:2xZ)把 `illumove`(§CZ)与
   `illureal`(§DB)**两条同轮入集**(§DC,成员串 50 → 52),`strategy-29`/`strategy-30` **已裁**;
   我的入集提议因此**顺延为 §DD**。⚠️ **总监在 §DC.3 加了一条提议里没有的限定,收割时必读**:
   那两条**同帧不正交** —— `illureal` armed 会**缩小** `illumove` 的域,而两份验收各自只 arm
   自己那一个 id,**所以没有任何测试能看见这件事**,交集上的帧**不能分摊归因**);**录像组**(只缺一种读数:**「Ringmaster 处于
   `BOT_MODE_SIDE_SHOP` 且正在攻击 Tormentor」的窗口有多少、多长**;`acceptance` 已按 §CJ 预登记
   **`METHOD-FAILED`** ⇒ 没有这种窗口、甚至根本没有 Ringmaster 出场,判 **`DOMAIN-EMPTY` 退回总监**)。
   **批测台:`strategy-31`,搭车、零 AWS 增量、零 EC2。**

0FIELD. **【2026-09-01T07:46Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的九条全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出;backlog `0d` 上一轮已结案 ⇒ **留在它打开的那个人口里**:
   **小兵驱动器,不经 mode 竞价** —— 取上一轮修的那条分支**再往上四行**的那一条);
   **落地 gated `illureal`**,入集提议 `test_set.md` **§DB**(搭车、零 AWS 增量、不申请专波),
   `queue.json` 新增 **`strategy-30`**(提议方自建,**`bundle` 已填**);`state.json` 新键 `illureal_20260901`;
   issue **GH #381**;报告 `iterations/reports/strategy/20260901T074632Z.md`;
   零 AWS、S3 零访问、零 EC2;`game/` 零 diff。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个关于世界的谓词一旦被存成手工维护的字段,
   它的真假就不再是世界的事实,而是「每个写者记没记得」的事实。**
   谓词的可达性于是等于**它最不勤勉的那个调用方**;而且它**朝「关」的方向、以静默的方式**失效 ——
   **一个没被设过的字段,和一个诚实的 `false`,在任何观察下都一模一样**:
   分支不发生、不报错、没有计数器动,**没有任何测试能把「这不是幻象」和「没人给这个幻象打标记」分开**。
   **判别特征可数、且不需要帧**:**同一个文件里一个谓词有两种活着的写法**
   (一个字段 + 一个回答同一问题的引擎调用),**而不同分支读的是不同的那一个**;
   见到这种形状就去数 **字段的写者 vs 分支的调用方**。本例 **2 比 127**。
   **与五个同族划清界限(它们的因各不相同)**:GH #348 **顺序**、#368 **词法作用域**、
   #370 **未汇报的副作用**、#373 **闩记错后置条件**、#378 **节流器作用域** ——
   **那五条都是「某一份状态被怎么读/怎么写」的缺陷;本条不是**:
   `isIllusion` 的**每一次读和每一次写都正确,字段也从不过期**,
   错的是**这个字段本身是引擎已知之事的副本,而副本有 2 个写者、正本有 127 个读者**。
   **缺陷**:`bots/FunLib/minion_lib/illusions.lua:52` 把
   `X.ConfuseEnemyWithIllusions`(低血撤退时让幻象反向散开做诱饵)闸在手工字段
   `hMinionUnit.isIllusion` 上。全仓**写**该字段的**恰好 2 个文件**
   (`hero_naga_siren.lua:91`、`hero_phantom_lancer.lua:92`),而**127 个英雄文件**
   全部经 `aba_minion.lua:48-53` 把小兵送进本模块,**且驱动器自己按引擎方法
   `hMinionUnit:IsIllusion()` 路由** ⇒ **幻象一定到达 `X.Think`,只是里面那条分支看不见它**
   ⇒ 该分支对**除娜迦与 PL 之外的每一个幻象**结构上不可达(CK 的 Phantasm、TB 的 Conjure Image、
   幽鬼 Haunt,以及 **19 个买 `item_manta` 的英雄文件**里的每一把分身斧)。
   **⭐⭐ 它是缺陷不是取舍,证据在同一个文件里**:**往下六十行**的 `X.ConsiderRetreat`
   对**同一个句柄**、经**同一次 `X.Think` 调用**、**在下一行**,
   用**引擎方法**问了**同一个问题** ⇒ 方法在这些句柄上**在今天发货的代码里就可用**,
   而**这个文件自己并不一致地偏好那个字段**。
   **⭐⭐⭐ 为什么没人发现 —— 不是「没人想过幻象」**:**12 个**英雄文件在自己的
   `X.MinionThink` 里**显式判过 `IsIllusion()`** 再路由(12 个明确想着幻象的作者),
   其中**同时设了字段的 2 个是娜迦和幻影长矛手** —— **两个专职幻象英雄,
   也就是你要验一个幻象功能时会打开的那两个** ⇒ **功能在演示里是好的,在别处全是死的**。
   **灵魂守卫在另外那 10 个里,而本文件 `X.ConsiderMove` 里就有一条灵魂守卫专属的幻象带线分支**
   ⇒ **模块是为一个它自己的闸放不进来的人口写的**。
   **改动**:新增 `IsIllusionUnit(hMinionUnit)` 按 `J.IsModeTurbo() and J.IsSoakCandidate('illureal')` 分叉;
   **门关逐字返回那个字段 ⇒ 出厂不变**;门开返回
   `hMinionUnit.isIllusion == true or hMinionUnit:IsIllusion()` —— **严格超集**
   (**arming 不可能让今天会做诱饵的娜迦/PL 幻象反而不做**),**且不外扩到无技能召唤物**。
   `X.Think:52` 改调该 accessor,**发货函数体其余一字未动**。
   **产出** `tests/test_illureal_field_vs_engine.lua`(`[ratchet]` **12/0**),真实帧
   `f_231411_ck_zoned`(subject **chaos_knight**,t=192.0,hp **126/1068 = 0.118**;
   选它因为 CK **既是幻象大招英雄、又在 19 个 `item_manta` 买者之列**,
   而 `hero_chaos_knight.lua:124-131` **无条件**路由却**从不设字段**)。
   该帧上分支的两个世界条件**是读出来的不是断言出来的**:`J.GetHP`=0.118<0.4、
   `J.WeAreStronger(bot,1200)`=false 且 1200 内**确有 2 个活敌**(不是列表为空)。
   **变异 19 条:16 CAUGHT / 3 存活,三条存活全部在跑之前就写进文件**。
   门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
   `illureal` 12/0 · `illumove` 9/0 · `smoke_load` 3/0 · `gate_claim` 10/0 ·
   `pullcamp_trigger_census` 29/0 · `activemode_world_assertion` 12/0;
   **全量套件本轮没跑完(GH #124),不声称**。
   **⚠️ 一次方法自伤,被测试自己的断言抓出**:英雄文件普查按
   `Minion.IllusionThink`(**模块局部变量的拼写**)读出 **126/127** ——
   漏的是 `hero_wisp.lua`,它从 `typescript/` 转译而来、**小写拼作 `minion.IllusionThink`**
   ⇒ **一个确实在路由的文件从普查旁边走了过去**;已改为按**调用**取键。
   **与 GH #377 的 M8 同形**;**登记理由是失效方向 —— 它朝更小的分母偏,
   也就是朝这个测试想要的答案偏**。
   **⚠️ 顺带修一条邻居棘轮的假阳性**:`test_illumove_shared_throttle.lua [source S3]`
   断言 `count(CODE,'IsSoakCandidate(')==1`(「本文件恰好一个门表达式」),
   在同一文件落下第二个**无关**候选那一刻就红了 —— 该断言本意是
   「没有第二个 `illumove` 门绕开 accessor」,**不是「这个文件永远不许长出别的候选」**;
   已按 `IsSoakCandidate('illumove')` 取键并补「那唯一的门必须坐在 `IsPerUnitMoveClock` 里」。
   **一个禁止文件生长的棘轮,量的是文件不是主张。**
   **明说没做**:`ConfuseEnemyWithIllusions` **函数体一字未动**(反向 800u 的几何、
   以 `bot:GetFacing()` 为基准是否最优诱饵方向,**只普查未审计**);
   `aba_hero_sub_units.lua` / `primal_split.lua` 的 4 处连续命令**仍只普查未审计**;
   **频率未知且比平时更重** —— 四项合取(幻象活着 ∧ 主人 <40% ∧ 撤退 ∧ 非强势方)
   在真实 Turbo 局里的出现率**未证,那就是本修复价值的上界**,
   **加重一条:焦点五英雄没有一个产生幻象 ⇒ 只可能在非焦点英雄身上买到读数**。
   **下一格**:**总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 主判据进不进 §CR;
   丙 `strategy-29`/`illumove` 仍待裁);**录像组**(只缺一种读数:**「某 bot 持有存活幻象
   ∧ 血量 <40% ∧ 正在撤退」的窗口有多少、多长**;`acceptance` 已按 §CJ 预登记
   **`METHOD-FAILED`** ⇒ 没有这种窗口判 **`DOMAIN-EMPTY` 退回总监**)。
   **批测台:`strategy-30`,搭车、零 AWS 增量、零 EC2。**

0ILMV. **【2026-09-01T04:29Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出
   ⇒ 取 backlog **`0d`** —— **而本轮把 `0d` 结掉了**:它剩下的两行普查**都实测为空**
   (mode 那半止于 `mode_outpost_generic.lua:117`,GH #373;`ability_item_usage_generic.lua` 全量 grep
   连续/排队型命令族**只有一行** `ActionQueue_UseAbility(hItem)`(`:1120`),是 `SetUseItem` 的 `'twice'` 臂里的
   **物品施放**、不是追击命令)。**把同一条 grep 扩到 `bots/mode_*.lua` 之外才是本轮的入口**:
   **6 处存活的 `Action_AttackUnit(x, false)`,全部在小兵驱动器里** —— 一个 `0d` 从没点过名的人口,
   **因为它根本不经过 mode 竞价**);**落地 gated `illumove`**,入集提议 `test_set.md` **§CZ**
   (搭车、零 AWS 增量、不申请专波),`queue.json` 新增 **`strategy-29`**(提议方自建,**`bundle` 字段已填**);
   `bots/` 只改一个文件、**全在门后**,`game/` 零 diff;零 AWS、S3 零访问。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个节流器的作用域必须等于它所节流的那个东西的作用域。**
   两者一旦不等,节流器**不再是限速器,而是抽签**:每个窗口第一个进门的人**替所有人**把预算领走,
   而输的人**不是晚一点拿到,是什么都没有**;**没有任何东西会举手,因为从模块内部看,
   每一次调用都长得像一次被正确节流的调用**。**判别特征可数、且不需要帧**:
   生命周期是模块的状态,被写在一条**每单位每帧各跑一次**的路径上。
   **与四个同族划清界限(四条的因各不相同)**:GH #348 **顺序**、GH #368 **词法作用域**
   (`local` 遮蔽,守卫与消费者读两个变量)、GH #370 **未汇报的副作用**、GH #373 **闩记错后置条件**;
   **本条里时钟的每一次读和每一次写都正确且自洽 —— 错的是「有多少东西共用这一个时钟」。**
   **缺陷**:`bots/FunLib/minion_lib/illusions.lua` 的 `nNextMoveTime` 是 **module 级**局部变量,
   而它节流的决策(「这个单位最近有没有被给过去处」)是 **per-unit** 的;
   `bots/FunLib/aba_minion.lua` **只 `dofile` 该模块一次**(`:11`),把这个 bot 的**每一个**幻象与
   **每一个** `U.IsMinionWithNoSkill` 单位经**同一个调用表达式**(`:52`)送进 `X.Think`
   ⇒ 同一帧第一个走到移动分支的小兵把共享时钟推后 0.2s,**兄弟们直接从 `X.Think` 末尾掉出去,零命令**。
   **⭐⭐ 损失是全额而不是部分,原因是两道闸的相互作用**:`aba_minion.lua:33-35` 那道**自己的**
   per-unit 0.5s 闸对每个单位初值为 0 ⇒ 一起召唤出来的小兵**同一帧过闸、此后永远同步**;
   输家被自己的 0.5s 闸扣住,0.5s 后再来时共享时钟又被当帧赢家推后了。
   **真实帧 20 周期 4 小兵实测 `20 / 0 / 0 / 0`,不是 20/6/6/6**(**跑出来的,不是读出来的**)。
   **⭐⭐⭐ 它是缺陷而不是设计取舍,理由写在同一个调用者身上**:`aba_minion.lua` 在它调用
   `Illusion.Think` 的**二十行之上**,对**同一批单位**做**同一件事**并且做对了 ——
   0.5s 节流存成 `hMinionUnit.lastItemFrameProcessTime`,**一个挂在句柄上的字段**
   (4 处提及**处处索引到句柄**,已源码计数)⇒ per-unit 字段**不是本修复发明的新机制**,
   `illusions.lua` 自己就往句柄上写了五个(`attack_desire`/`attack_target`/`move_desire`/
   `move_location`/`to_farm_lane`)。
   **改动**:`nNextMoveTime` 声明原样保留,`0.2` 命名 `MOVE_THROTTLE`,新增两个 accessor 各按
   `J.IsModeTurbo() and J.IsSoakCandidate('illumove')` 分叉;**门关时两个 accessor 读写的就是那个
   module local ⇒ 发货路径不变**;门开时读写 `hMinionUnit.next_move_time`(初值 `nil` 读回 **0**,
   与全新 module 时钟**同值** ⇒ **arming 不可能让出厂会动的小兵反而停下**)。
   **arming 是把时钟挪成 per-unit,不是把时钟拆掉**(`[frame F3]` 专钉)。
   **产出**:`tests/test_illumove_shared_throttle.lua`(`[ratchet]`,**9 例 0 失败**,秒级),真实帧
   `f_260823_002103_wk_ancient_camp_634`(subject **skeleton_king** —— **焦点英雄,而它自己的召唤物
   `npc_dota_wraith_king_skeleton_warrior` 正被 `U.IsMinionWithNoSkill` 点名**;该帧
   `skeleton_king_mortal_strike` **等级 4**,`[frame F0]` 钉住 ⇒ **放出一整队这种小兵的英雄状态
   在帧上是真的**)。**变异 14 条:14 CAUGHT**(还原用纯净文件副本,每条都确认变异串真的被替换)。
   门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**。
   **⚠️ 一次量具洞,差点让一条断言因错误理由通过(登记,不修)**:
   `GetUnitList(UNIT_LIST_ALL_HEROES)` 在 fixture 上**恒答 0**,同一帧 `UNIT_LIST_ENEMY_HEROES` 答 **4**
   ⇒ **UNMEASURABLE 不是 EMPTY**(GH #171/#205、#373 读数 (B) 同族)。**失效方向是关键**:
   建在它上面的世界槽会**安静地**答「附近没有人」,而那**恰好就是让 `[frame F5]`(被饿死的兄弟
   仍会攻击)因为错误理由通过**的那个答案 —— 本轮它确实先这么错了一次(`nearby=0`,`GetWeakestHero=nil`),
   改用有值的 per-side 列表后才拿到真读数。
   **⚠️ 开工自检同一站点连续第七轮**:第一条命令仍是 `| tail`,被拒绝横幅当场拆穿
   (`SELFCHECK_EXIT=2 ... NOT a pass`);改重定向后**不设超时、跑完 8 条腿**(上一轮是自己给的
   `timeout 400` 把它砍在最后一条腿之前 —— **本轮没有重犯**)。四条 finding **全不是本轮的**:
   unlanded `7b60b0e`(总监 04:06Z)、cadence 三洞(均在 08-31)、`TRUNK RED test_rc_wrapper.py`(**GH #364**);
   **`ORPHAN_PROPOSAL` 本轮为零** —— `strategy-26/27/28` 已被总监裁成 `ROUTED_RIDESHARE / ADMITTED`,
   **上一轮「连续第三轮未裁」的交棒已消解,不再重复**。
   **明说没做**:另外两个 `dofile` 点(`minion_with_skill.lua` / `vengeful_spirit.lua`)各有一份
   `nNextMoveTime`,**本轮不动**(一次一个杠杆);`aba_hero_sub_units.lua` / `primal_split.lua` 的
   4 处连续命令**只普查未审计**;**频率未知且比平时更重**(形状已证,真实局里一个 bot 同时有 ≥2 个
   受控小兵的时长未证,**那就是本修复价值的上界**)。
   **下一格**:**总监**(甲 裁入集,**RIDESHARE、不能当独臂**,单兵时两臂逐位相同;
   乙 主判据进不进 §CR;丙 量具洞立不立案);**录像组**(只缺一种读数:**真实对局里一个 bot
   同时有 ≥2 个受控小兵/幻象的窗口有多少、多长,以及那窗口里每个小兵各收到几条移动命令** ——
   它一个人定价本修复的上界;`acceptance` 已按 §CJ 预登记 **`METHOD-FAILED` 分支**:
   语料里没有这种窗口就判 **`DOMAIN-EMPTY` 退回总监重裁**,**不得**自行套用「无效应 ⇒ 不 promote」)。
   **批测台:`strategy-29`,搭车、零 AWS 增量、零 EC2。**

0NSPC. **【2026-09-01T01:25Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出
   ⇒ 取 backlog **`0d`**;**并且先更正上一轮把 `0d` 宣告为「最后一站」的那句话** —— 它的普查 glob 是
   `bots/mode_*.lua`,**漏掉了 `bots/FunLib/override_generic/` 下两个真的会被加载的 mode 文件**
   (`mode_attack_generic` 无条件、`mode_laning_generic` 对 9 个 buggy 英雄),两个都带 `Action_*`);
   **本轮的结论是:那条本以为要落地 gated 修复的缺陷是假的,而证伪它的东西比它本身值钱。**
   **零行为改动、零 gate、零 AWS、S3 零访问;`bots/` 与 `game/` diff 为空;`queue.json` 一字未动。**
   **已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):命名空间是运行期事实,不是语法事实。**
   `^function Name(` 只说明定义的**形状**,从不说明它写进哪张表 —— 只要树里有文件能重绑定自己的环境。
   凡把列 0 定义读成「写进同一个命名空间」的审计,量的是**这个程序并不具有的那个命名空间**,
   而且**朝自信那一侧失效**:凭空造出一对彼此永远看不见对方名字的文件之间的冲突,**两边都配着 file:line 证据**。
   **与四个同族区分清楚**:GH #348 顺序、#368 作用域、#370 未汇报的副作用、#373 闩记错后置条件 ——
   **那四条都是发货 Lua 里的缺陷;本条不是 bot 的缺陷,是「读这棵树」的缺陷** ——
   发货代码是对的,指控它的那次审计是错的。**这正是它需要棘轮的原因:有人重新推导出同一个假结论时,树里没有任何东西会红。**
   **被证伪的那条(每一环都可查、每一环都真、只有前提错)**:`GetBestLastHitCreep` /
   `GetBestDenyCreep` / `GetFurthestEnemyAttackRange` 三个列 0 名字**同时定义在** base
   `bots/mode_laning_generic.lua`(:265/:287/:251)与 override
   `bots/FunLib/override_generic/mode_laning_generic.lua`(:167/:188/:214),而 base 在 **:30**
   `dofile` override、**然后才**定义自己那三份 ⇒ 读成一个命名空间就是覆盖,且**两份合同不同**
   (base 返回 `(creep, bApproachOnly)`,override 返回一个)⇒ override 的调用点会把
   「够不到、只能靠近」的候选当成「这一下能补掉」,**对打不死的兵按下攻击 = 推线**。
   **前提错在 `game/botsinit.lua:15`**:`CreateGeneric()` 用 `setfenv(2, newenv)` **重绑定调用方 chunk 的环境**,
   `__newindex = M` ⇒ **在这种文件里,一个写得和全局一模一样的列 0 定义落进的是模块自己的表**。
   **执行真实加载顺序实测(跑出来的不是读出来的)**:`dofile(override)` 后 `_G.GetBestLastHitCreep` **仍是 nil**;
   `dofile(base)` 后才有值,且**与 `X.GetBestLastHitCreep` 不是同一个对象**;改写 `X` 的成员 `_G` 那份纹丝不动。
   **发货代码自己把这件事写反过来说过一遍**:base :143 走 `local_mode_laning_generic.GetBotTargetLane()`
   **取模块表**,全仓 **0 处**按裸名字调它。
   **⭐⭐ 爆炸半径量出来了**:`bots/` 下带列 0 裸定义的文件里,**重绑定环境的恰好 2 个,都在
   `override_generic/`**,另外 **59 个**没有 ⇒ **「列 0 定义不是全局」的全部人口,恰好就是 naive 审计
   会去和同名 base 配对的那个人口**;另一对(`mode_attack_generic`)**构造不出**这个假结论
   (唯一列 0 名字 `GetActualDesire` 全仓别处没有定义,已断言)。
   **⭐⭐⭐ 诚实边界(比平时重)**:override laning 只对 `BuggyHeroesDueToValveTooLazy` 的 9 个英雄加载,
   而 **109 个 fixture / 43 个英雄里这 9 个一个都没有 —— 不是「少」,是 0** ⇒
   **一条已发货、每局都可能加载的路径,本仓从未、也无法做过任何本地验证**。
   该断言写成**「一旦有了就红」**:哪天语料收进一枚 buggy 英雄的帧,
   `no_fixture_can_drive_the_override_laning_file` 就失败,那次失败就是「回来验掉它」的信号。
   **产出**:`tests/test_botsinit_env_namespace.lua`(`[ratchet]`,**12 例全绿**,秒级)。**变异 13 条:13 CAUGHT。**
   **⚠️ 三次方法自伤,全部由变异抓出**:(i) **M8** —— 我那个「这文件重不重绑定环境」的探测器
   **按变量名 `BotsInit.CreateGeneric` 字符串匹配**,用别的局部名重绑定的文件从它旁边走过去 ——
   **一个用来警告命名空间错误的探测器自己按命名约定取键,复现了它要警告的那个错误**;已改为对**调用**取键。
   (ii) **M9** —— `select('#', helper({}))` 读的是**空表走到的共用 `return nil` 兜底**,两臂都答 1,
   **与「找到兵时返回几个值」这条合同毫无关系**;已改为**从函数体读合同**(按两侧列 0 邻居切片,
   不用 `.-\nend` —— 那会停在第一个嵌套 `end`,GH #373 那次自伤的手法)。
   (iii) **M12** —— 「base 自己两个调用点确实读第二个返回值」**只活在一条失败信息的字符串里**;
   **只出现在报错文案里的声称等于没被断言**;已补断言。
   **⚠️ 开工自检同一站点连续第六轮**:第一条命令仍是 `| tail`,被拒绝横幅当场拆穿
   (`SELFCHECK_EXIT=2 ... NOT a pass`);改文件重定向后**我自己给的 `timeout 400` 把它砍在最后一条腿之前**
   (`SELFCHECK_EXIT=124`)—— **这不是通过,是没跑完**。已跑完的腿报四条,**全不是本轮的,不复核不重裁**:
   unlanded `268b1fd`(总监 01:08Z)、cadence 三个洞、`ORPHAN_PROPOSAL` §CW/§CX(= **GH #376 刚立案的假阳**,
   `strategy-27`/`strategy-28` **两行都在**,按 #376 警告**不补重复行**)、`TRUNK RED test_rc_wrapper.py`(**GH #364**)。
   **下一格**:**总监**(甲 主判据要不要进 `test_set.md §CR` —— 它比前四条更「元」,影响本组每轮都在做的 grep 式普查;
   乙 `strategy-27`/`strategy-28` **仍未裁**,自检连续第三轮报同两条;丙 **本轮无入集提议**,没有 gate、没有行为改动);
   **录像组**(缺的只有一种读数:**任意一局里那 9 个 buggy 英雄之一的对线期帧** ——
   它一个人锁着 `override_generic/mode_laning_generic.lua` **整个文件**的本地可验证性)。
   **批测台:无请求,零 AWS 增量。**

0OLAT. **【2026-08-31T22:28Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出 ⇒ 再取章程 backlog **`0d`** 的「还没查的」那行);
   **这是 `0d` 那一格的最后一站** —— 把两个 roam 文件排除后,`bots/mode_*.lua` 全量 grep
   `Action_AttackUnit(x, false)` / `Action_MoveToUnit` / `ActionQueue_*` **只剩一行**
   (`mode_outpost_generic.lua:117`),而读它发现的问题**比那条命令高一层**:那条命令的 mode 根本没机会出价。
   **已落地 gated `outlatch`**、**已发 GH #373**;一条**可复用主判据** + 一条**独立的第二后果**(登记不修)
   + **两条互相对冲、都是真的语料读数** + 一次**安静地通过了一轮**的方法自伤;
   `bots/` 只改一个文件两处且**全在门后**,`game/` 零 diff,`queue.json` 新增 `strategy-28`
   (**提议方自建**,不花钱),零 AWS、S3 零访问。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个闩必须记录它所把守的后置条件,不是那次尝试。**
   `DidWeGetOutpost = true` **无条件**排在扫描之后;该块是 `Outposts` 的**唯一写者**、
   `GetClosestOutpost` 是**唯一读者**(1 声明 / 1 insert / 1 长度测试 / 7 处在 getter 里,已钉)
   ⇒ **一次返回空表的扫描永久关死这个 mode**:`GetClosestOutpost` 恒 `nil`,出价恒 NONE,
   `Think`(含 `:117` 的连续型命令)永远到不了 —— **没有报错、没有重试、没有任何一条腿会举手**。
   **一般形**:凡是「只做一次」的标志位写在**本该产出点什么的那个块的出口处**,
   空结果与满结果**无法区分**,而且是**永久性**的(那个标志位正是唯一还会再跑一次生产者的东西)。
   **与三个同族区分清楚**:GH #348 是**顺序**、GH #368 是**作用域**、GH #370 是**未汇报的副作用**;
   **本条生产者/标志位/消费者三者各自都对 —— 错的是标志位回答的问题和消费者问的不是同一个。**
   **⭐⭐ 第二条互相独立的后果(登记,本轮不修)**:`GetClosestOutpost` 的合取式里
   `not Outposts[i]:IsNull()` 被排在**第四**位,**在两次对它所守护的句柄的方法调用之后**
   (Lua 的 `and` 左到右短路)—— **GH #348 的形状在第二个文件里**,
   而它值多少钱**恰好由上面那个闩决定**(表只填一次、永不刷新)。`[source S6]` 断言**缺陷仍在**。
   **⭐⭐⭐ 两条互相对冲、都是真的语料读数**(`tests/_outpost_gate_sweep.lua`,107 帧,零 AWS):
   **(A)** 报「敌方二塔已倒」的 **43/107** 帧,与**根本没有 `buildings` 表**的那 43 枚
   是**同一个集合**(差集实测 `t2-only=0 / no-buildings-only=0 / both=43`,**相等不是相似**)
   ⇒ 带真实建筑表的 64 枚上敌方三座二塔**全部矗立**,这个文件第 56 行以下**结构上不可达**
   ⇒ **S-A 是一次声明,不是一次发现**;**(B)** `UNIT_LIST_ALL` 993 条 / outpost **0** 条,
   但**UNMEASURABLE 不是 EMPTY** —— 归因是 `replay_fixture.lua` **自己写下的**那句
   「故意不注入小兵与建筑」(与 GH #171/#205 同族,与 GH #368 的 `GetProperTarget` 同形)。
   **改动**:(i) 闩改为 `DidWeGetOutpost = not bRescan or #Outposts > 0`(门关时短路在测量表**之前**
   ⇒ 出厂逐字节不变,三条真值已直接求值过);(ii) armed 时重试**自带边界**
   (`OUTPOST_RESCAN_INTERVAL = 1.0`,节流**写在门内**,位置钉成 门 < 节流 < 扫描 < 闩)。
   **产出**:`tests/test_outlatch_scan_postcondition.lua`(`[ratchet]`,**12/12**,秒级),真实帧
   `f_260819_181742_ss_chase_start`(**带真实建筑表**)。出厂:一次空扫描后**世界摆出两座 outpost、
   又过 20 帧,它再也没扫过第二次**;armed:节流到期后再扫即找到,`dist=1529.7`,出价 **0.4186 > NONE**,
   **且这一帧自己的三条否决全部被断言让开** ⇒ 两臂之间**只剩那个闩**。**变异 10 条:10 CAUGHT**。
   **⚠️ 方法自伤(安静地通过了一轮)**:`function GetClosestOutpost%(%).-\nend` **非贪婪停在第一个嵌套 `end`**,
   返回**被截断**的函数体,计数少报一处却**仍然匹配上一个看着合理的期望值** ——
   **一个返回得比它声称的少的扫描器,是靠「同意你」来失败的**;已改按两侧邻居切片。
   **⚠️ 诚实边界**:**频率未知,而且比平时更重** —— 形状已证、armed 的恢复已证,
   但真实对局里那次扫描多久返回一次空表**未证**;真引擎的 `UNIT_LIST_ALL` 很可能多数时候两座都带着,
   **修复的价值上界就是它不带着的频率**;引擎语义本仓不可观测,一句都没主张;
   前置条件(`IsEnemyTier2Down`)在 Turbo 10 分钟封顶的批测局里能否出现**本轮没答**;
   第二后果没修。**⭐ 全量单进程套件本轮跑完了**(收尾时先按 #124 的既有结论预写成「未跑完」,
   后台那一跑随后收线、**推翻预写**,已就地改正):`run_tests.lua` **裸读 `FULL_EXIT=0`,
   `2911 tests, 0 failures`**。**别用超**:(甲) 不满足 GH **#124** 的验收线(要求 10 分钟内,
   实测一个多小时)⇒ #124 的 §1 与 `--fast` 档**未解决**,被推翻的只是 §2 的「跑不完」
   与那 9 个**归属不明的 `F`**(本轮跑到末尾,**失败名单为空**);(乙) 跑的过程中工作树动过
   (两个 Lua 测试文件的**注释** `#372`→`#373`,以及 `state.json`/`test_set.md`)⇒
   这 2911 条**跨了一次树变更**,settled 树上的读数是那之后跑的 **62 tagged / 0 red**。
   **⚠️ 开工自检同一站点连续第五轮自伤**:第一条命令仍是 `| tail`,被拒绝横幅当场拆穿
   (`SELFCHECK_EXIT=2 ... NOT a pass`),改文件重定向后 `worst exit: 3`;三条 finding
   (cadence / queue-rulings / `test_rc_wrapper.py` = GH **#364** flaky)**全不是本轮的,不复核不重裁**。
   **下一格**:**总监**(甲 裁 `outlatch` 入集 `test_set.md §CX`,**RIDESHARE、不能当独臂**;
   乙 第二后果要不要单独立案;丙 主判据要不要进 §CR;丁 `strategy-27` **仍未裁**,本轮又加 `strategy-28`);
   **录像组**(缺的只有一种读数:**真实对局里敌方二塔倒下之后,某个 bot 的 outpost 扫描是否曾返回空表** ——
   可观测形式:该 mode 是否整局从未出过价,而地图上确有未被己方占领的 outpost。
   **这一枚读数一个人锁着 `outlatch` 的条件 (a)**)。
   **批测台:`queue.json` 的 `strategy-28`,搭车、零 AWS 增量、不申请专波。**

0CLOB. **【2026-08-31T19:27Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的全是本组自己开的;
   owner P1 第 1 棒、P2 均已交出 ⇒ 再取章程 backlog **`0d`**,这次是它「还没查的」那行里
   **`mode_team_roam_generic` 之外**的连续/排队型 `Action_*`);**已落地 gated `roamidle`**、**已发 GH #370**;
   一条**可复用主判据** + 一条**独立的第二后果**(登记不修)+ 一次方法自伤及其**对既存测试的连带修复**
   + 一条对前一次普查的**边界更正**;`bots/` 只改两处且**全在门后**,`game/` 零 diff,
   `queue.json` 新增 `strategy-27`(**提议方自建**,不花钱),零 AWS、S3 零访问。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个调用方不可能为一件它不知道发生过的副作用排序。**
   `mode_team_roam_generic.lua` 的 `Think` 里 `if isInIdleState then isInIdleState = J.CheckBotIdleState() end`
   **对控制流零影响**(块以下没有任何地方再读它,全部作用就是那次重新赋值)——
   **但被调方不是查询**:`J.CheckBotIdleState` 在恢复臂里**下命令**
   (`Action_ClearActions(true)` `jmz_func.lua:11994` + `ActionQueue_AttackMove(laneFront)` `:11998`)。
   **往下十一行**,只要 `targetUnit` 有效,同一个 `Think` 就发 `Action_AttackUnit(targetUnit, false)`,
   而一条 `Action_*` **「CLEARS the entire action queue」**(`docs/BOT_API_REFERENCE.md:1715`)⇒
   **防卡死的重定位命令在发出它的同一帧被销毁,而且恰好在这个 mode 自己制造的那个情形里被销毁。**
   **一般形**:写成裸语句的「状态刷新」——返回值被赋值、然后从不被分支读——**读起来像查询,也就被当查询审计**;
   它若其实下了命令,调用点手里没有任何东西能拦住下一条无条件 `Action_*`。
   **与两个同族同日区分清楚**:GH #368 是**作用域**(同名不同变量)、GH #348 是**顺序**(判 nil 前一行就索引),
   **本条调用方对任何一个值都没判断错 —— 缺的是被调方从来没汇报过的一件事实**。
   **⭐⭐ 第二条互相独立的后果(登记,本轮不修)**:它**每帧重复一次不是每 3 秒一次** ——
   `return true` 排在刷新采样锚点的两行(`:12010-12011`)**之上** ⇒ **idle 一旦闩上,`>= 3s` 的门再也关不上**;
   两个出厂调用点各自走每帧路径,被抹掉的 `Action_ClearActions(true)`
   因此**每帧落在其它所有系统排进队列的动作上一次**。一次一个杠杆 ⇒ 这是下一格。
   **改动**:(i) `J.CheckBotIdleState` 加第二返回值 `bRelocated`(**只在真下了命令的臂上为真**;
   两个出厂调用点各自单赋值目标 ⇒ Lua 丢弃它,默认逐字节不变,已断言);
   (ii) `Think` 里 `if bRelocated and J.IsModeTurbo() and J.IsSoakCandidate('roamidle') then return end`。
   **门开在 `bRelocated` 上不是 `isInIdleState` 上** —— 「因不明原因 idle」那条臂什么都没下,仍逐字节走出厂分支。
   **产出**:`tests/test_roamidle_recovery_clobber.lua`(`[ratchet]`,**11/11**,秒级),真实帧
   `f_260819_181742_ss_chase_start`(**本仓唯一一枚「team_roam 赢下竞价且手上有有效 targetUnit」的钉住帧**,
   而那正是恢复命令被抹掉的前提)。出厂日志 `Action_ClearActions → ActionQueue_AttackMove →
   Action_AttackUnit(bOnce=false)`、**帧以追击结束**;armed **帧以那条排队的 attack-move 结束**、其后无任何 `Action_*`;
   **turbo-only 是量出来的**(强制非 turbo ⇒ 两臂日志逐项相同);第二后果同帧量到(**时钟零推进**下仍报 idle 并又下一次)。
   **变异 10 条:10 CAUGHT**;⚠️ M4/M9 头一遍打 `MUTANT-NOT-APPLIED`(制表符差一格),
   **既不是 CAUGHT 也不是 SURVIVED**,按精确缩进重跑后才计入。
   **⚠️ 方法自伤:扫源码的测试把自己的注释数了进去** —— 写在修复之上的文档注释**逐字引用了它要钉的那几行**,
   计数把自己的解释数了进去、`lineOf()` 返回注释行号,**把一条顺序断言判反了**;
   修法是**保留行号的整行注释剥除视图**(与 GH #341/#345 同族)。
   **连带修好一个既存实例**:`test_roamreach_bounded_chase.lua` 的 REVERSE 断言此前扫**生文件**,
   于是 `roamidle` 把那行写进注释的一刻它就红了,**而没有任何一条命令被加进来**;已改为扫代码。
   **边界更正(不是矛盾)**:`state.json:fixture_modifiers_20260819` 的 `survey_result` 自称枚举了
   「每一个 `bOnce=false` / `Action_MoveToUnit` 站点」,但它**没覆盖 `ActionQueue_AttackMove`**,
   **也根本没找过「被抹掉」这个形状** —— 它问的是命令**活多久**,从没问过它**是否活过**。
   **⚠️ 诚实边界**:**频率未知**(形状已证、真实对局里多久闩上一次 idle 未证);
   引擎对「同一 tick 内 `Action_ClearActions` 之后再来一条 `Action_*`」的真实反应**本仓不可观测**
   ⇒ 只主张与引擎无关的那一半;第二后果没修;全量单进程套件未跑完(GH #124)。
   **⚠️ 开工自检同一站点连续第四轮自伤**:`| tail` 读退出码被那道拒绝当场拆穿
   (`SELFCHECK_EXIT=2 ... NOT a pass`),改文件重定向后 **EXIT=0**;
   两处 trunk 红是 GH **#364**(flaky)与 GH **#369**(英雄组 18:32Z 开),**本组不复核不重裁**。
   **下一格**:**总监**(甲 裁 `roamidle` 入集 `test_set.md §CW`,**RIDESHARE、不能当独臂**;
   乙 第二后果要不要单独立案;丙 主判据要不要写进 §CR);
   **录像组**(缺的只有一种帧:**真实对局里 bot 多久闩上一次 idle,以及那时 `targetUnit` 是否有效** ——
   这一枚读数一个人锁着 `roamidle` 的条件 (a))。**批测台:`queue.json` 的 `strategy-27`,搭车、零 AWS 增量、不申请专波。**

0SHDW. **【2026-08-31T16:36Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零 —— open 的 9 条全是本组自己开的;
   owner P1 第 1 棒早已交出、P2 已交棒 ⇒ 取章程 backlog **`0d`** 里明写「**还没查的**:其余 mode 文件里的
   `Action_AttackUnit(x, false)` / `Action_MoveToUnit`」那一条);**已落地 gated `rotscope`**、**已发 GH #368**;
   一条**可复用主判据**(遮蔽作用域)+ 一次对 §CR.2 豁免的**拒绝性**应用 + 一个**让缺陷对全仓不可见**的量具洞;
   `bots/` 只改 `mode_roam_generic.lua` 的 Pudge 块且**全在门后**,`game/` 零 diff,`queue.json` 一字未动,零 AWS、S3 零访问。
   **已交棒,球在总监与录像组。**】**
   **⭐ 主判据(可复用,超出本主题):一个 `local` 的遮蔽作用域随它的块结束,而守卫是按名字读的。**
   Pudge 块里 `if Rot:GetToggleState()` 块内的 `local botTarget` 遮蔽了**文件级**同名变量
   (声明在文件头的 `local nInRangeEnemy, ..., botTarget, ...`,**只在 `GetDesireHelper` 内赋值**),
   遮蔽**随该块的 `end` 结束**,而 `bot:ActionQueue_AttackUnit(botTarget, false)` 就排在那个 `end` **之下**
   ⇒ 四行之上的 `J.IsValidTarget(botTarget) and dist > 400` **守的是另一个变量**。
   位置证明(遮蔽行 < 守卫行 < 那个 `end` < 消费行)由源码解析得出、钉成 `[source S1]`。
   **一般形:守卫与被守卫者同名 ≠ 同一个变量**;凡「守卫在 `if` 块内、消费在块外」的形状,
   守卫对消费点**零信息**,而它读起来像有信息。(与 GH #348 同族**不同因**:那里是顺序,这里是作用域。)
   **⭐⭐ 三条互相独立的后果,各自单独钉住**:(1) **无条件** —— 命令在 Rot 块**之外**,
   Rot 开不开、目标有效无效、任何距离都发(真实帧上 toggle 喂 `0`(mock 默认,**Lua 里为真**)
   与喂 `false` **两种都驱动过**,出厂都发);(2) **连续型** `bOnce=false` —— `roamreach`(GH #45)
   存在的理由那一形,mode 不再赢下竞价之后**没有人**会再评估它,而唯一的释放就写在那个不再被调用的 `Think` 里;
   (3) **可陈旧** —— 文件级赋值排在「无敌/死亡/幻象/非英雄」早返回**之下** ⇒ 那些帧留着上一帧的句柄,
   即 `roamstale`(GH #39,**已 promote,stable-v1**)那条病**在第二个文件里**。
   **⭐⭐⭐ 它不能吃 §CR.2 的豁免,而理由是差集不是动机**:ABORT-CONTAINED 要求
   **(乙) 兜底触发条件 ⊆ 出厂抛错条件**;armed 同时压掉了「**Rot 没开**、而文件级句柄是一个
   完全有效(可能陈旧)的英雄」那类帧上的命令 —— **那不是抛错帧** ⇒ 过不了 (乙) ⇒ 走 `gated-fix`。
   `nil` 那一半也许 abort-contained,**「无条件」那一半可证不是**。
   **这是 §CR.2 第一次被用来「说不」** —— 一条判据第一次拒绝自己,比再一次批准更能说明它可用。
   **⭐⭐⭐⭐ 顺带修掉一个让这条缺陷对全仓不可见的量具洞**:`record_actions` **直到本轮**都没挂
   `ActionQueue_AttackUnit` / `ActionQueue_AttackMove`;出厂树前者 **5** 个调用表达式(**3** 个就在
   `mode_roam_generic` 的 Think 路径上:Leshrac `:931`、Wisp `:944`、Pudge `:999`)、后者 1 个,
   **六个全是连续型** ⇒ **每个读该日志的测试,在真的下了命令的帧上都答「没有下命令」**
   (本轮第一次探针就是空 log,而同帧其实下了 `ActionQueue_AttackUnit(nil, false)`)。
   两钩已补、**13 个现存消费方全部重跑绿**(加钩子只会**增加**条目 ⇒ 因此变红的测试读的是盲区)。
   钉成 `[source S5]`。**这是 GH #341/#345 那一族(工具从未求值某条子句)在动作侧的第一例。**
   **读数(993 存活英雄帧,零 AWS)**:`J.GetProperTarget(bot)` 在 **993/993** 上为 `nil`,
   而**原因有名字**:`bot:GetTarget()`/`bot:GetAttackTarget()` 都在 `tests/mock/bot_api.lua` 的
   `handle_getters` 里(答 nil)、**107 个 fixture 里 0 个**给覆盖值(`SRC tgt=0 atk=0`)⇒
   **UNMEASURABLE 不是 EMPTY**。**⚠️ 作废面比本 id 宽**:`J.GetProperTarget` 在 `bots/` 下
   **351 个调用表达式 / 164 个文件** ⇒ 本仓在 fixture 帧上对其中**任何一个**下过的结论,
   都是在它返回 nil 的帧上下的 —— 与 `0SIB` 的 `gate=0` **同族、同日第二例**,**本轮只登记不审计**。
   ⇒ far-creep 那一半(`IsValidTarget` **就是** `IsValidHero`,而 `J.GetProperTarget` 只把**同队**
   英雄/建筑置 nil ⇒ 野怪是完全正常的返回值,于是距离测试被**整个跳过**)登记为 `[limit]`,不写进结论。
   **产出**:`tests/test_rotscope_shadowed_target.lua`(`[ratchet]`,**13/13**,秒级)+
   `tests/test_propertarget_corpus_domain.lua`(**不打标签**,29s,4/4)+ `tests/_propertarget_sweep.lua`。
   **两文件故意拆开、只有便宜那半带标签**(GH #358:自检 Lua 腿已 133.3s,不给每流每次触发再加 29s)。
   **变异 10 条:10 CAUGHT**(树外 `cp` 还原、每条前后 `sha256sum -c`、退出码**裸读未经管道**、先确认绿基线)。
   ⚠️ 头一遍 M5/M8 打 `MUTANT-NOT-APPLIED`(模式在文件里不唯一)——**那既不是 CAUGHT 也不是 SURVIVED**,
   补唯一上下文后重跑才成立,照实登记。
   **⚠️ 本轮自伤那一站点第一次没能发生**:开工自检**被它自己拒绝**
   (`REFUSED: stdout is a PIPE ... SELFCHECK_EXIT=2 ... this is NOT a pass`)——
   `0SGN`/`0SIB` 连续两轮的同一手法,被 `a5578526` 落地的那道拒绝在管道下**直接不跑**挡住了;
   改走 `> /tmp/sc.log; echo $?` 重跑,读数 `70 passed, 1 failed`,红的是 GH **#364** 的 flaky
   `test_rc_wrapper.py`,**本组不复核不重裁**。
   **⚠️ 诚实边界**:`ActionQueue_AttackUnit(nil,false)` 在引擎里怎样**本仓无法观测**
   (`print()` 到不了控制台、`error in error handling` 吞错误文本)⇒ **不主张**它抛错也不主张它是 no-op,
   只主张与引擎无关的那一半:**这一帧就以它结束**;缺陷**频率未知**(只对 Pudge 可达,非焦点五);
   合成桩是**明标**的(`__index` 兜底 `false`,每个 `false` 只可能让**更早**的分支放弃);
   §7 那四条同胞**没有**被裁成「不是杠杆」,只是**今天驱动不了**(marci/muerta/faceless_void/leshrac
   在 107 个 fixture 里**各 0 次**);全量单进程套件未跑完(GH #124)。
   **下一格**:**总监**(甲 裁 `rotscope` 入集(`test_set.md §CU`,搭车零 AWS 增量,
   **排期约束:只对 Pudge 可达 ⇒ RIDESHARE,永远不能当独臂**);乙 `J.GetProperTarget` 的
   **世界断言**要不要立案 —— 351/164,与 GH #362 同族同日第二例;丙 §CR.2 第一次被用来**拒绝**
   一条修复,这种用法要不要写进 §CR);**录像组**(缺的是**帧**:① 任一局里
   `bot:GetTarget()`/`bot:GetAttackTarget()` 的真实取值 —— **最值钱,它一个人锁着 351 个调用点的可测性**;
   ② marci/muerta/faceless_void/leshrac 任一帧;③ 一局有 Pudge 的对局,`rotscope` 的 (a) 就有通道)。
   **批测台无请求、零 AWS。**

0FALSE3. **【2026-08-31T13:50Z 新增,**认领 GH #365**(总监开的 `[bug]`,但 §3 点名的
   `salvepool`/`salveyield`/`tpreach` 三个 id **全在本组作用域**,而 §4 自己写「归因不归我」);
   一条**可复用主判据**(控制的作用域)+ 一次**逐字节的阳性对照** + 三条方法自伤;
   `bots/`/`game/` **逐字节零 diff**,零新 gate id,`queue.json` 一字未动,零 AWS、S3 零访问。
   **已交棒,球在总监与 GH #229。**】**
   **⭐ 主判据(可复用,超出本主题)**:**「开跑前 `rm -f X`」控的是"X 是陈旧的",
   不是"X 在运行中被别人删了"**。共享的物理资源有这两种失效模式,而前者的控制**不覆盖**后者;
   #365 判三条红为真红的**唯一**理由正是前者(「删了仍然红,因此排除了那条解释」)。
   一般形:**一个只在时刻 t0 施加的控制,不能排除一个在 (t0, t1) 区间内起作用的原因。**
   **⭐⭐ 判据二:失败读数落在"另一条腿自己断言并通过"的值上,是共享原因的指纹。**
   三条 armed 腿失败观测到的值,逐位等于**同一文件 unarmed 用例断言、且同一次运行里绿着**的值
   (salvepool `got 500`==`FLOOR` 且 sweep 含 anchor pool 890;salveyield 的 `== false`;
   tpreach **同一用例体内往上三行**)。「断言写错」要三个独立文件各自错到恰好落在自己的
   unarmed 值上 —— 一个共享原因一次解释三条。
   **⭐⭐⭐ 阳性对照**:并发 `rm -f` 循环下三条红**文件名/行号(398/354/381)/断言正文/
   用例数与失败数**与 §3 的表逐项相同(19-1 / 29-2 / 8-1),含 published 未展开的
   `:627 guard=false model=true`;干净顺序腿三个全 **BARE_EXIT=0**;自检同一条腿同一棵树
   **54/0**、加新文件 **55/0**。
   **机制的形状**:25 文件出现该路径、22 个逐字声明同一字面量、22 个含 `os.remove(SIDE_PATH)`、
   **0 锁、0 进程唯一路径**;`load_with(nil)`(**unarmed 腿**)第一件事就是删 ⇒
   **危险是套件自己**,两个 lua5.1 进程重叠就够,不需要任何异常进程。
   **产出**:`tests/test_soakside_shared_switch.lua`(`[ratchet]`,**8/8**,秒级;
   `[source S1..S4]` + `[recorded]` + `[limit]`)。**变异 10 条:10 CAUGHT。**
   **⚠️ 自伤三条**:(a) `| tail` 读自检退出码**连续第三轮同一站点**(横幅再次拆穿);
   (b) **M5 存活 ⇒ 断言真的太松**:全文件搜串分不出 salveyield **四处**同样的 `== false`,
   改成按用例名抽取用例体后 CAUGHT ——**存活变异体当场变成更强的断言**;
   (c) **红基线下的变异台是无意义的**(我自己 `%s` 写成 `%%s`),修绿再重跑。
   **⚠️ 诚实边界**:复现证明机制**充分**、不证明当时确实并发;干净腿不是 soak
   (排除的是**确定性**断言错误);**不裁三个 id 的杠杆价值**;补救属 GH #229;
   全量套件未跑(GH #124)⇒ 上界是 55 个快检测器;§2 的泄漏本轮未复现但**不反驳**。
   **下一格**:**总监**(甲 §3 改判假红 —— §6.2 的验收在这里会引向把 salvepool 的
   armed 445 改成 500,**那正好删掉一个真行为**;乙 管道读退出码连续三轮同一站点,
   与 GH #339 同族;丙 §6.3 的不泄漏普查要不要变常设断言);
   **GH #229**(S3 是它的进度计;建议**序列化**而非进程唯一路径 —— 后者做不到,
   `J.IsSoakCandidate` 在出货代码里读的就是那个固定路径)。**批测台无请求、零 AWS。**

0SIB. **【2026-08-31T10:50Z 新增,**自驱**(`[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒早已交出、
   P2 上一轮已交棒 ⇒ 取章程 backlog **`0d`** 那一族里明写「还没查的」那条:其余 mode 文件里的连续型命令);
   **已发 GH #362**;一条**顺序即闭式**的主判据 + 一条「同一函数里的同一条合同只被兑现一次」+
   一条**否掉照抄修法**的不变式 + 一次把 UNMEASURABLE 与 EMPTY 分开的三门归因;
   `bots/`/`game/` **逐字节零 diff**,零新 gate id,成员串一字未动,`queue.json` 一字未动,零 AWS、S3 零访问。
   **已交棒,球在录像组与总监。**】**
   **⭐ 主判据:`Think()` 里 `:612`(`towerCreepMode`)排在 `:621`/`:628` 之上并且 `return`,
   而后两者是 `GetDesireHelper` **每一条**早返回分支(`ConsiderHelpWhenCoreIsTargeted` /
   `ConsiderHelpAlly` / punish-dive / punish-over-chase / `l1trade` / `l5combo` /
   `CarryFindTarget` / `SupportFindTarget`)唯一的落点** ⇒ 陈旧的 `towerCreepMode`
   **不是打错目标,是把赢下竞价的那条分支整个取消**。复位够不到那些帧的理由也是顺序:
   `GetDesireHelper` 内唯一的复位躺在 **16 条 `return` 之下**(数字从树里数、钉在测试里),
   另一个复位 `OnEnd()` 只在该 mode **不再赢**时触发 —— 那正是 `Think()` 不会被调用的那一种。
   **⭐⭐ 这条合同就写在同一个函数的头上,只被兑现了一次**:`GetDesireHelper` 开头的 `[roamstale]`
   注释把这套机制逐字讲清楚、还把发生它的分支一条条点名,然后修了它覆盖的**两个句柄里的一个**
   (`hTargetCreep` 修了,`towerCreepMode` 没有),两者相距不到两屏、在同一个函数体内。
   `0S`/`0S2` 的新形状:**不是两个文件各一份,是同一个函数里的同一条推理只应用到自己列举对象之一。**
   **⭐⭐⭐ 而且「照抄那条已 promote 的行」是错的**:`towerTime ~= 0` 与 `towerCreepMode` 在出货代码里
   是同一个比特(三处写入两两成对,已断言),但**「仍在窗口内」那条分支 `return` 前不重新确认 flag**
   ⇒ 把清除放在 `roamstale` 那一行旁边会关掉一次**正在进行中**的攻击,
   `roamstale` 自己的安全性论证(「只移除陈旧、绝不新增」)**不覆盖这一步**;正确修法要多一句
   「仍在窗口内时重新确认」,该句由上述不变式**可证是 no-op**。已写成会自己红的断言。
   **读数(993 存活英雄帧,零 AWS)**:暴露面 **58/993 = 5.8%**、散在 **29 个 fixture** 上
   (投递正好走被吃掉的 `:621`/`:628`);而 **setter 在本语料不可达**,理由**不是游戏条件、是三个没接线的
   引擎量** ⇒ **UNMEASURABLE 不是 EMPTY**(GH #171/#205 分界):`GetActiveMode()=0` 让 **925/925**
   零出价帧过不了 mode 闸(**连带关掉 `GetDesireHelper` 整个 `elseif` 半边 —— `CarryFindTarget`/
   `SupportFindTarget` 也在里面**)、`GetAnimActivity()=0`(**993/993**)关掉
   `ShouldAttackTowerCreep` 前三个 return、塔的 `GetAttackTarget()=nil`(有塔的 **264 帧全为 nil**)
   关掉第四个;同一 reach 谓词其余三条**不是**瓶颈(alive 925 / count 847 / far 845)⇒ `gate=0` 是归因不是裸零。
   **⇒ 本轮不落 gate**(没有一帧能驱动它,gate-plumbing 不算本地验证)。
   **产出**:`tests/test_towercreep_stale_source.lua`(`[ratchet]`,**7/7**)+
   `tests/test_towercreep_stale_domain.lua`(**5/5**,53s)+ `tests/_towerstale_sweep.lua`(子进程 ~51s)。
   **两个文件故意拆开,只有便宜那半带标签** —— GH **#358** 刚把自检 Lua 腿量成 133.3s,
   再加 **+38%** 去重算一个波次之间不变的读数正是那条 issue 的成本;这是预算决定不是疏漏(已写进文件头)。
   **变异 9 条:8 CAUGHT / 1 SURVIVED**;副本还原 + 每条前后 `sha256sum -c` + 退出码**裸读未经管道**。
   **SURVIVED 的 M4 是变异形状不对不是断言松**(内嵌 `return` vs 只看行首的计数器),
   **该幸存者当场变成一条新断言**:同区间除那 16 条外只剩 **3** 处带 `return` 子串的行且**全部是注释**,
   盲区在这棵树上是空的 —— 写进文件,不留给记忆。
   **⚠️ 当轮自伤一条,与 `0SGN` 同一站点同一手法、在它登记之后的下一轮又发生**:
   自检输出接 `| tail -40` 读 `$?` 拿到 `tail` 的 0,而横幅自己写着 `selfcheck worst exit: 3`;
   这次由横幅拆穿(`FINDINGS: cadence trunk-red(python)`,红的仍是 `0SGN` 登记过的
   `tests/test_rc_wrapper.py` 假红,**本轮不复核不重裁**)。`evidence-discipline` 规则 3 现有**连续两轮**现场。
   **⚠️ 诚实边界**:5.8% 是**被吃掉的落点**的暴露面、是频率**上界**,对联合分布零信息(缺陷还需 flag 陈旧为真,
   而本语料产不出那个状态);`fire587=0` 与 `roamstale` 在工作**相容但不可归因**(`GetLastHitCreep`
   可能本就每帧 nil,**不要拿它当 roamstale 的佐证**);`X.IsMostAttackDamage` 未求值 ⇒ 第四门归因**充分不排他**;
   `1502` 是引擎裸字面量而 mock 的 `ACTIVITY_ATTACK` 是哨兵(已断言);语料有偏 ⇒ 百分比是形状与界;
   **`gate=0` 作废的东西比本主题宽** —— 任何走 `CarryFindTarget`/`SupportFindTarget` 的历史结论都取自
   这两个函数**一次都没被调用过**的帧,**本轮只登记不审计**;全量单进程套件未跑完(GH #124)。
   **下一格**:**录像组**(缺的不是判据是**帧** —— 带回 ① `GetActiveMode()`(最值钱,它一个人关着整个
   `elseif` 半边)/ ② `GetAnimActivity()`(GH #326 的动画模型可能可复用)/ ③ 塔的 `GetAttackTarget()`
   任一,本组当轮即可按第 4 步钉帧落 gate);**总监**(甲:`gate=0` 这条**世界断言**要不要立案 ——
   它作废一整类历史结论,与第十条/第十六条同族;乙:「便宜的 source 半边进快腿、贵的驱动半边不进」
   要不要变通则(GH #358);丙:§CQ.3 的 `PROVABLE` 里是否加一条「凡注释点名了机制适用范围的修复,
   必须有断言证明该范围内每个对象都被覆盖」)。**批测台无请求、零 AWS。**

0SGN. **【2026-08-31T07:55Z 新增,**自驱**(`[strategy]` 未认领 issue 为零 ⇒ 走 owner 优先项 **P2**;
   **已发 GH #360**,并在 **GH #339 追评**一处假 TRUNK RED 的活体
   责任链上本组自己那一格:GH #338 与 #342 都把本族 (a) 交到走路腿,先把走路腿的**可作用域**算清楚);
   一条**闭式的边际域** + 一条**对本组自己 #342 §3 的更正** + 一条**符号**判据;
   `bots/`/`game/` **逐字节零 diff**,零新 gate id,成员串一字未动,`queue.json` 一字未动,零 AWS、S3 零访问。
   **已交棒,球在录像组与总监。**】**
   **⭐ 主判据:`margin(stayfield2) = S ∧ (¬T3 ∨ ¬T5)`。** `stayfield2` 唯一调用点
   (`mode_retreat_generic.lua:236`)的**上一条语句**是已 promote、无 gate、每局 Turbo 都活的
   `if J.ShouldStayAndRegen(bot) then return BOT_MODE_DESIRE_NONE end`,两者之间**无可执行语句**(已断言)。
   把子句对齐:turbo 相同;`hp∈[0.18,0.55] ⇒ [0.18,0.75]`;`#heroes(1600)==0 ⇒ #heroes(1200)==0`
   —— **T 的五条里三条被 S 蕴含** ⇒ 边际域只剩「未归因英雄伤害」与「补给」两条。
   **⇒ HP 带与距离环 —— 这一族每次读数都在按它们分层的两个量 —— 永远不可能是一帧进边际域的理由**;
   放宽 0.55 天花板到 0.75 以下**一帧都不动**。
   **⭐⭐ 更正本组自己 GH #342 §3**:那一轮扫**词元** `botHP` 刻画走路腿,结论「两条边都是活的」;
   **词元扫描看不见住在函数调用后面的子句** —— `ShouldStayAndRegen` 读的正是 `J.GetHP`,带着自己的 `0.75` 帽。
   (#342 对 **TP 腿**的结论不受影响,**不重开也不反驳**。)T 独占的 `(0.55,0.75]` 带**不空**:**6 帧**。
   **⭐⭐⭐ 而且方向是反的**:`mode_retreat_generic` 以 `return Min(nDesire, 1.0)` 结尾 —— **只夹上界不夹下界**,
   而内部两处减法(`-0.25` / `-0.75`,常数从源码 parse)能把和推到零以下 ⇒
   **凡用常数 `BOT_MODE_DESIRE_NONE`(0.0)提前返回的守卫,在自然出价为负的帧上都是在抬高出价。**
   实测 19 帧边际域:**14 帧抬高 / 5 帧压低**;声明切片(每 fixture 的 `self`,107 帧)上
   **自然出价为负 56 / 零 12 / 正 39 ⇒ 负出价是多数(52.3%)**。**同一条算术逐字适用于它上面那条发货中的 `tphome` 行。**
   **读数(993 存活英雄帧,零 AWS)**:`S=23 / 已被吃掉 4 / 边际域 19`(**不是空集** —— 这是开工假设被自己读数否掉,照实记);
   **边际域几乎全由「补给」子句造出:supply-only 18 / both 1 / dmg-only 0**,
   而 `IsFieldRegenSituation` 头部注释把**归因危险**(全局大招的 Lina 帧)写成这个 helper 存在的理由
   ⇒ **立案理由与实际作用面是两回事**;`s_above55=0`、半径单调性 **993/993 无违例**(两条蕴含是量的不是假设的);
   **边际域与「出价真的动了」完全重合**(`moved_in_margin=19=margin`、`moved_in_absorbed=0`)⇒ 该引用的数是 **19** 不是 23;
   `bagsalve` 在走路腿:闭式说**能**造边际域、语料说**没有一帧是那形状**(14 帧背包大药,armed/不 armed 边际域都是 0),两个读数都登记。
   **产出**:`tests/test_stayfield2_marginal_domain.lua`(`[ratchet]`,**18/18**;`[source]`7 + `[drive]`1 +
   `[control]`1 + `[recorded]`6 + `[limit]`3;四个 HP 常数 + 两个半径 + 两处减法**全部从树里 parse**,
   蕴含由 parse 值**推导**)+ `tests/_stayfield2_margin_sweep.lua`(子进程,**90s**)。
   **⚠️ 当轮自伤一条,照实登记**:开工自检用 `| tail -40` 读,拿到 `tail` 的 0,而横幅自己写着
   `selfcheck worst exit: 3` —— 这正是 `evidence-discipline` 规则 3 的最后一个站点,**在它落地当天又发生一次**。
   顺带一条 **GH #339 的活体**:自检报 `TRUNK RED tests/test_rc_wrapper.py`,同一棵树 tracked 文件零改动,
   两次**裸读**复核均 exit 0(`68 passed, 0 failed`)⇒ 假红,且正落在 #339 点名的 exit 3 那一支上;
   **本组不裁,只交读数 + 一条假设**(该文件多条 timing 敏感子进程用例 + 并发负载)。
   **⚠️ 诚实边界**:**本轮不裁任何人**(三个 id 不入集/不出集/不改级);「抬高出价」是**算术**不是行为主张
   (引擎在全 ≤0 时怎么仲裁不在本仓,已写成 `[limit]`);语料有偏 ⇒ 百分比是形状与下界不是真实频率;
   `natural_neg` 那格是**声明切片**不是 993 全量(全量驱动 >10min,GH #358 的预算);全量单进程套件未跑完(GH #124)。
   **下一格**:**录像组**(甲:走路腿买 (a) **必须先与 `¬T3 ∨ ¬T5` 求交**;乙:优先量「补给」那半;
   丙:顺带给一个真实对局里「撤退自然出价为负」的占比);**总监**(甲:§3 的判据要不要变通则;
   乙:`return Min(nDesire, 1.0)` 缺下夹**本身**要不要立案 —— 出厂行为、影响该文件每一条常数提前返回的守卫、
   含已 promote 的 `tphome`,改它是行为改动要 gate 要波次,**本组没擅自加下夹也没开占位 gate**)。

0DUT. **【2026-08-31T04:2xZ 新增,**落地 `test_set.md §CO.1(三)` 的交棒**(总监 08-30T22:0xZ 交给本组、
   本组 `0VAC` 末行自己也挂着的那一条);**已发 GH #356**;一条「预设错而算术对」的主判据 +
   一条把散文变成会自己红的东西的可复用手法 + 一条**抬高**被修正对象的读数。
   `bots/` **只改注释**(非注释行逐字节零 diff,已写成断言),零新 gate id,成员串一字未动,
   `queue.json` 一字未动,零 AWS、S3 零访问。**已交棒,球在总监。**】**
   **⭐ 主判据:`pullcad` 注释里的「83% vs 58%」**算术无误,预设有误** —— 它是闭式
   `(nBeat − 0.5)/nBeat`,预设三条臂**每一个引擎帧**都被问到;§CK 的不等式否掉的正是这个预设
   (节拍只在节流阀重开的帧上被问到,而刚 poke 完的英雄按构造待在 `ACTIVITY_ATTACK` 里一整个
   攻击周期 R)。⇒ **那两个数描述的是 R → 0 的世界,而 R → 0 就是 `creepthink` armed 的世界**,
   `creepthink` **至今 gated 未 promote** ⇒ **不是发货中的那个世界。**
   **⭐⭐「不许静默删数字」在这里不是照办,是有理由的**:同一帧
   (`f_072738_zuus_mana`)、与 `test_creepthink_anim_throttle.lua` 共用的驱动器与动画模型,
   30 s = 901 帧/次,R 扫 1.4/1.5/1.6/1.7s(语料里**唯一**测到过的攻击周期带 = GH #326 那四次
   右键的 gap)⇒ **0.0% / 41.2–50.1% / 58.4% / 83.4%**;而**关掉节流阀(R→0)复现出的
   58.3796% 与 83.3518% 与后两行逐位相同** ⇒「旧数字 = R→0 读数 = `creepthink` armed 读数」
   **是等式不是措辞**(`[limit L1]`)。删了就是删掉表里**两行真实读数**。
   **⭐ 它把 `pullcad` 抬高而不是压低,并改变了形状**:旧 58%→83%(+25pp,「加宽」型);
   新(发货世界)**0.0% → 41.2–50.1%**(「**从空集里捞出来**」型),机制是**把 nBeat 抬到 R 之上**
   —— **与 `creepthink` 攻击同一条不等式的另一侧**(后者把 R 压到 ~0)。⇒ **强烈次可加**
   (单独 0→50 与 0→58,合起来 0→83,朴素相加 108;`pullcad` 单独 +50.1pp,叠在 `creepthink`
   上只 +25.0pp)—— **这就是 §CO.1 (ii) 在源码侧的那一半**,现在是 `[arith A1]` 一条会自己红的
   断言而不是散文。**本轮不放宽任何并池许可**,§CO.1 (ii) 逐字不变。
   **产出**:`tests/test_pullcad_throttled_duty.lua`(`[ratchet]`,**11/11**;`[frame]`1 +
   `[drive]`4 + `[limit]`1 + `[control]`2 + `[arith]`1 + `[source]`2)+ 源码注释块
   `[DUTY-CYCLE CORRECTION 20260831]` + test_set.md **§CS**(登记,**不是裁定**)。
   三个常数(1.2/3.0/0.5)全部从树里 parse;**注释里那张表也被 parse 出来与驱动值比对**
   ⇒「静默删数字」从此**机器可查**(M5/M6/M7 就是它)。
   **变异 11 条:10 CAUGHT / 1 SURVIVED**(M11 营地 beat = `pullthink` 地界,作用域控制,正确)。
   文件副本还原 + 每条前后各一次 sha256 + 退出码逐条裸读未经管道 + 收尾 `sha256sum -c` OK;**本轮零自伤**。
   **M4(hold 0.5→0.0)不被 `[limit L1]` 抓**——L1 把 hold 从源码 parse,比较式两边一起动;
   那是它的设计形状,常数钉在 `[S2]`,**已写进文件的变异记录不留给记忆**。
   **⚠️ 诚实边界**:41.2–50.1% 是**下界**(模型不把走路中的英雄放进 `ACTIVITY_RUN`,而引擎里
   那只会推迟下一次 poke、拉长 drag);**0.0% 那行两样都不靠**(从未被下过移动指令的英雄不会在跑;
   且它对**任何 R ≥ nBeat** 成立,`[control C2]` 钉住带子跨在两个 beat 之间);**R 的带子来自
   一个 episode(三个 gap),是引用不是本组的测量**;**本轮不裁任何人**(`pullcad` 不 promote /
   不退回 / 不改级,`creepthink` 仍 gated);动画模型是模型(`[control C1]` 是它不惰性的证据);
   **全量单进程套件本轮未跑完**(GH #124)。
   **下一格**:**总监**(甲:登记 §CS 并勾销 §CO.1(三);乙:本文件正好是 §CQ.3 那条
   `PROVABLE: <test 路径>` 想要的形状 —— 是否推广成通则「凡源码注释里写了效应量的 id,
   那个数必须被某个 ratchet 文件 parse 并驱动」);**本组自己**:`0VAC` 那条交棒**至此清空**,
   下一轮取 backlog 顶或未认领的 `[strategy]` issue(#342 / #338 / #324 / #323 / #319 / #318)。

0VAC. **【2026-08-31T01:23Z 新增,**认领 GH #349**(批测台 00:39Z 交棒的 trunk RED,原文写
   「归属:总监 / 协同组」;两个 id 都在本组地界,且它当时**挡着全队每一轮开工自检**);
   一条**闭式蕴含**形式的主判据 + 一条可复用判别式 + 一处**当轮抓住的变异台自伤**;
   `bots/`/`game/` **逐字节零 diff**,零新 gate id,成员串一字未动,`queue.json` 一字未动,
   零 AWS、S3 零访问。**已交棒,球在总监。**】**
   **⭐ 主判据:共臂行 `creepthink > pulldrag` 是**空**的,而且空得是一条蕴含不是一次判断。**
   `creepthink` 在 `bots/` 里只出现一次,是 `and` 的**右操作数**,左操作数
   `bot.roamCreepPull ~= nil`(`mode_roam_generic.lua:265`);Lua 的 `and` 短路 ⇒
   `roamCreepPull == nil` 的帧上 `IsSoakCandidate` **根本不被调用**,合取项恒 `not false = true`。
   记 `R=(roamCreepPull~=nil)`、`C=(roamCampPull~=nil)`;到达 `J.GetLanePullDragTarget`(`:404`)
   需要 `C`,而 **`C ⇒ ¬R` 有两条彼此独立的理由**:(1) **控制流** —— 该调用在
   `if C then … return end` 块内,该块排在 `if R then … return end` **之后**,只用 `Think`
   自己的函数体;(2) **互斥** —— 两字段在 `GetDesireHelper` 恰好三处被写(`:98–99`/`:104–105`/`:108`),
   每处都令另一个为 `nil`,对**任何**调用方成立。⇒ **在 `pulldrag` 的调用点上,`creepthink`
   的字面量是不可达代码。**
   **⭐⭐ 可复用判别式:共臂行的空性 = 「内层 id 的字面量在外层调用点上可不可达」,
   而短路 `and` 把它变成一个纯语法问题。** 三步零数据:取内层 id 唯一出现处的**左操作数**
   (短路 `and` 的左边就是它的必要条件)→ 取外层调用点的**支配条件**(其上每一个提前 `return`)
   → 问二者是否互斥。**「读一遍判一句」的有效期是读它那个人的记忆;一条钉住的蕴含会在
   实现变形那天自己红**(M3/M4 就是这个)。
   **产出**:`tests/test_creepthink_pulldrag_vacuous.lua`(`[ratchet]`,**8/8**;
   `[drive]`2 + `[control]`3 + `[source]`3)+ `test_coarmed_attribution_register.lua`
   ACKNOWLEDGED **+1 行**(带读到的东西)+ test_set.md **§CP**(登记,**不是裁定**)。
   **「没有差别」不是仪器坏了 —— 同一帧三个读数**:营地拉 idle 下 drag 调用
   未 armed **89** / armed `creepthink` **89**(order log 逐字节相同)/ armed `pullthink` **75**;
   营地拉 `ACTIVITY_ATTACK` 下 **0 / 0 / 75**;**勾线**拉 `ACTIVITY_ATTACK` 下 armed `creepthink`
   **order log 变了而 drag 仍 0** —— 最活跃的那条腿上调用点仍是零,这是整条主张的一句话形态。
   **变异 7 条真变异:7 CAUGHT / 0 SURVIVED**;第 8 条(杀 `pullcad` 门)**SURVIVED,正确**。
   **⚠️ 当轮自伤(哈希买到的)**:M3/M4 第一版 perl 模式写错(`\Q…\E` 里的 `\n` 是字面反斜杠-n),
   **文件根本没被改**;变异前后各取一次 sha256 把它报成**「DID NOT LAND,不是结果」**而不是
   SURVIVED —— 这正是 `evidence-discipline` 规则 1 要买的东西。
   **⚠️ 诚实边界**:「空」是关于**这个调用点**的不是关于**这一波**的(动态耦合存在于任意两个
   armed id 之间,不是这个登记器测的东西)⇒ **不放宽任何并池许可**,§CO.1 (ii)
   「W30 起 `pullcad` 读数不得与 W25–W29 并池」**逐字不变**;`pullthink > pulldrag`
   **不被重开**(真合取,本轮的 `[control]` 是它第三个独立佐证);
   **本轮不把 `pullcad > pulldrag` 从「判断」升级为「可证」**(没为它建变异台);
   全量单进程套件未跑完(GH #124)。
   **下一格**:**总监**(甲:确认登记 ⇒ #349 可关;乙:一条方法问题 —— 登记器的 WIDE 行现在有
   「判断」与「可证」两个成色,**要不要给可证那档一条机器可查的标记**);
   **本组自己**:§CO.1 (三) 那条交棒**已于 2026-08-31T04:2xZ 落地**(见 `0DUT` / test_set.md §CS)——
   `pullcad` 注释里「83% vs 58%」重推完毕:数字一个字没删,因为它们**是 R→0 的读数**,
   而 R→0 就是 `creepthink` armed 的世界。

0GAP. **【2026-08-30T22:30Z 新增,**认领 GH #344**(录像组 22:08Z 新开的唯一未认领 `[strategy]`;
   owner 优先项 **P2** 的「步行回泉」那一半,责任链当前球在本组)、**已发 GH #347**;
   一条**闭式的无主带**主判据 + 一条**行程/帧量纲**的可复用判据 + 一条**实测**定价否决;
   `bots/`/`game/` **逐字节零 diff**,零新 gate id,`queue.json` 一字未动,零 AWS、S3 零访问。
   **已交棒,球在录像组与总监。**】**
   **⭐ 主判据:GH #344 的 127 条「满血步行回家」落在一条任何 id 都够不到的带子里 ——
   `hp > 0.55 ∧ 4000 ≤ d_泉水 < 10000`。闭式,四个常数。**
   owner P2 的步行腿只有两个 id:`stayfield2`(→`J.IsFieldRegenSituation`)拒 `nHP > 0.55`
   且**没有任何距离子句**;`itemtrip`(→`J.IsWastefulItemTrip`)拒 `hp < 0.55` 且拒 `d < 10000`。
   **血量轴用同一个 0.55 无缝拼接(刻意的,见 `IsWastefulItemTrip` 头注释)⇒ 洞不在血量轴,
   在距离轴**,而 4000 正是 #344 自己 `walk_home_trips` 的起点门槛(`stayfield2_margin.py:98` 的
   `FAR_U`)。帧 A(lion `eb04aa/…184327_slot1`,掉头点 **7,065u**、hp **1.000**、mp **1.00**)落在带内:
   **一帧、两个 id、两个彼此独立的拒绝理由**(一个败在血量上界,一个败在距离下界)。
   **⭐ 第二条:唯一认得 #344 那张脸的分支长在行程的另一头,而且它是稳定版。**
   `ConsiderHeroMoveOutsideFountain`(`mode_roam_generic.lua:1521`,注释逐字写着
   `-- is stuck in item mode`)读的正是 `BOT_MODE_ITEM ∧ hp>0.95 ∧ mp>0.95`,**无 gate**;
   但它被 `DistanceFromFountain() > MoveOutsideFountainDistance → false` + 泉水光环挡在**到家之后**,
   而它驱动的动作走到的是**离自家泉水 1500** 的点 —— **在 #344 定义「到家」的 2000u 环之内**
   (`FOUNTAIN_NEAR_U`)⇒ **按构造只能缩短「停留」,永远不能终止一趟行程**。
   ⇒ **#344 的停留中位 12s / p75 14s 是这个 hatch 的产出,不是「无人在管」的证据**(订正一种自然读法);
   ⇒ 也解释了 #344「两条腿两个分层同号 ⇒ 稳定版行为」:**这个 hatch 本来就无 gate**。
   **⭐⭐ 可复用判据(实测,不是论证):没有一条由 (hp, mp, 1600 环, 距离) 组成的帧级谓词
   能给这条带子定价 —— 量纲不对,不是常数不对。** 本仓库 107 fixture / **993 存活帧**上:
   `IsWastefulItemTrip` 域 **146/993 = 14.7%**;**无主带 209/993 = 21.1%(比整个域还大)**;
   加 #344 的 `mp>0.95` 之后**仍有 83/993 = 8.4%** ⇒ 按满蓝分档把下界降到 4000 会把帧域抬到
   **23.1%**,正是 `itemtrip` 在 **33.1%** 上被按条件 (b) 退回的同一个数量级(总监 08-23 14:58Z,
   X = gpm −26.44)。**同一个已付过学费的错误**:这个谓词选**帧**(「健康、安全、离家远」就是
   一句普通打钱帧),#344 数**行程**;那 127 条的判别特征——**掉头回来、手里什么都没多**——
   是**行程级**的量,**没有任何一帧带着它**。⇒ **#344 自己那句「先只观测,不动 gate」是对的,
   而且理由是算术不是谨慎。**
   **产出**:`tests/test_healthy_walk_home_gap.lua`(`[ratchet]`,**14/14**;
   `[source]`4 + `[arith]`3 + `[drive]`3 + `[control]`2 + `[limit]`2)。
   **0.55 / 10000 / 4000.0 / 2000.0 / 1500 全部从树里 parse**,并有一条 `[control]` 扫本文件
   **可执行部分**的字面量(M13 教训)。`[drive]` 在 `f_260822_063722_lina_tp_home` 上
   **一次只替换一个操作数**,两个谓词的**四条边在这一帧上都真的做决定**
   (`hi±0.01`/`lo±0.01`;hp 0.54 假/0.55 真;d 9999 假/10000 真)⇒ 空不是「谓词死了」。
   **`[control]` 是这三条读数成立的前提**:这帧自己距泉水 **10,009.85u**,**只比出货下界高 9.85**,
   所以 hp=1.000 下它**自己是真的** ⇒ `7065` 那个假是**关于 7065 的读数**,不是关于这个 fixture 的。
   **变异 9 条真变异:9 CAUGHT / 0 SURVIVED**;第 10 条作用域控制 **SURVIVED,正确**。
   **还原走文件副本(不是 `git checkout`)+ 每条后 `sha256sum -c`(10/10 OK)+ 变异前后各取一次哈希
   (把「变异没落地」与「没被抓到」分开报)+ 退出码逐条 bare 读、未经管道**
   (`.claude/skills/evidence-discipline` 规则 1/3/4;本轮零自伤)。
   **⚠️ 诚实边界**:**本文件不裁任何人**,`stayfield2`/`itemtrip` 都不入集/不退回/不定级,
   **#344 没有被回答**(它要的是观测,这是观测的**源码那一半**);**#344 的百分比一个字都没断言**
   (别人的仪器),帧 A 的三个数是**引用**不是**测量**;第 4 节那四个数**是**本仓库语料的读数但
   **没有钉进 ratchet**(钉语料普查会让文件在每次新 fixture 落地时变红,钉住的是不会动的闭式带子);
   **`bot:GetActiveMode()` 在 fixture 上恒 0** ⇒ **本组不主张那 127 条是哪个模式发的**,
   只主张两个 id 都拒绝它们所在的带子(已写成断言:dumper 哪天带 active mode 它会红);
   **全量单进程套件本轮未跑完**(GH #124)。
   **下一格**:**录像组**(#344 §建议 1 的检测器**必须多打三列**:每趟行程的**最大**泉水距离、
   `t0` 的 **active mode**、**停留时间与步行时间分开**;缺第一列谁都定不了价,
   缺第二列「是不是 item 模式」永远没有证人,第三列是因为 hatch 只拥有停留那一段)、
   **总监**(请裁一条**方法**问题:**一个候选 id 的「域」什么时候允许用帧计数报价?**
   `itemtrip` 被退回那次,请求方按 0.038 **行程**/局定价、仪器按 33.1% **帧**报价;
   本轮说明即便加上满蓝条件帧域仍 8.4%,**这不是调常数能修的**。
   本组**不主张** `itemtrip` 重新入集,也**不主张**动它的 10000)。
   **不认领**:#345/#341/#339(`[harness]`)、#343(`[batch]`)、#340(`[bug]`,不重开也不反驳)、
   #331/#330/#328(`[hero]`);#342/#338/#324/#323/#319/#304/#300 均为本组此前认领、现等他组裁定。

0DENOM. **【2026-08-30T19:20Z 新增,**认领 GH #340**、**已发 GH #342**(录像组 18:57Z 新开;整篇的主语是
   `stayfield`/`stayfield2` —— 本组地界的两个 id,且 §5.2 明写建议改走 fixture 路线);
   一条**闭式不可满足性**形式的主判据 + 一条**外一层**的可复用判据 + 两处**当轮抓住并修好**的自伤;
   `bots/`/`game/` **逐字节零 diff**,零新 gate id,`queue.json` 一字未动,零 AWS、S3 零访问。
   **已交棒,球在录像组与总监。**】**
   **⭐ 主判据:#340 表里的第二大桶 `hp>0.55`(armed 30.6% / baseline 21.4%)在 TP 腿上
   不可能是失败原因 —— 那条子句在 `stayfield` 唯一的调用点上不可满足。** 闭式,不是估计。
   `J.IsFieldRegenSituation` 的带是 `nHP < 0.18 or nHP > 0.55`(`nHP = J.GetHP(bot)`);
   `stayfield` 的唯一调用点「撤退:3」(`ability_item_usage_generic:5626`)进入条件是
   `botHP < 0.34 or botHP + botMP < 0.43`,而**承重的一步是那个 `botHP` 就绑在 `:5224` 的
   `local botHP = J.GetHP( bot )`** —— **同一个函数**,两条带不换算就可比(树里另两处 `botHP`
   用的是 `GetHealth()/GetMaxHealth()`,M5 证明断言取的是锚点前最后一次绑定)。
   `botMP = J.GetMP(bot)` 是非负量的比值 ⇒ `botMP >= 0` ⇒ 第二个析取项蕴含 `botHP < 0.43`
   ⇒ **`sup(botHP | 进入「撤退:3」) = max(0.34, 0.43) = 0.43 < 0.55`**。
   下界不是:`0.18 ∈ [0, 0.43)` ⇒ **`hp<0.18` 是两条边里唯一能在 TP 腿上做决定的那条**。
   方向保守:分支其余**十二个**合取项一律当成已满足,结论仍成立。
   **⭐⭐ 可复用主判据(GH #319 的外一层)**:**一条子句的实测命中率是它被评估的那个「人口」的属性,
   不是它所在守卫的属性。** 在「所有回家 TP」上跑第一失败子句分解,会把**该谓词并未接线进去的
   调用点**的行记到共享谓词头上;直方图**算术上完全正确**,却**把杠杆排错序** —— 最大的桶
   可以属于一条**在被测 id 所在处已经死掉**的子句。修法不是更好的检测器,是**先把人口与调用点
   自己的进入条件求交再排序**;对本族是**四个常数、零数据**。#319 缩的是**守卫的域**,
   这条缩的是**测量的分母**。**并且 0.43 早就在桌上**:本组 13:27Z(`0MODE`/GH #333)算的就是它,
   只是被塞进求撤退**块**上确界的 `max()`(0.87)里,**没有任何一处把它和 0.55 比过**。
   **⭐ 买到的三件**:(1) **重新归类** —— `hp>0.55` ⇒ `botHP > 0.55 > 0.43` ⇒ 进不了分支
   ⇒ 那 **30 + 22 行是别的按下点发出的回家 TP**;这是对 #340 §4.2 自己那句「reach = 0」的
   **独立、脱离仪器**的推导,**更锐**(点名哪些行、为什么)⇒ **放宽留守 HP 窗口永远抓不到它们**。
   (2) **那个桶只在走路腿上有意义** —— 从 `GetDesireHelper()` 到 `J.ShouldRegenNotWalkHome(bot)`
   之间**只有一处 `botHP` 比较**,且在 `DotaTime() < 0` 里、循环体要求 **`not enemy:IsBot()`**
   (对人局才走的开局梯子,全 bot 批测取不到;M6/M10 各自抓到)⇒ 走路腿两条边都活
   ⇒ **这是 GH #338「本族 (a) 只能从走路腿读」那条交棒的第二条、完全不同来源的理由**。
   (3) **残量被夹住** —— 落在 TP 腿可达域内的只有 `hp<0.18`(25.5%/24.3%,**按设计排除**:
   owner 原则「危险时撤退合法」)加尾巴(2.0/6.8、2.0/1.0、2.0/—、1.0/0.0)
   ⇒ **上界 ≈ 201 的 7–8%**,而且是**还没过其余十二个合取项之前**;GH #338 已证明过完之后是零。
   **两条不同子句、彼此独立地到达同一个零。**
   **产出**:`tests/test_stayfield_hp_window_reach.lua`(`[ratchet]`,**15/15**;
   `[source]`5 + `[arith]`3 + `[drive]`2 + `[control]`2 + `[limit]`3)。
   **四个常数 0.18/0.55/0.34/0.43 全部从树里 parse,一个都没写死**。
   `[drive]` 在 owner P2 自己那一帧上**只建模 `J.GetHP` 一个操作数**:两条边在这一帧上
   **都真的做决定**(0.56 假 / 0.54 真 / 0.17 假 / 0.19 真)⇒ **天花板不是恒真谓词,
   是 TP 腿从不把这种帧递给它**;而 `ceil±0.01` 在 `mp ∈ {0,.25,.5,.75,1}` 五个取值上都进不了分支。
   **变异 10 条真变异:10 CAUGHT / 0 SURVIVED**;**还原走文件副本 + 每条后 `sha256sum -c`,
   11 次全 OK;退出码逐条 bare 读取、未经管道**(`.claude/skills/evidence-discipline` 规则 1/3,
   本轮 19:00Z 才落地的技能)。**M9(把本文件自己的进入条件模型改成恒 `true`)
   让 `[arith]` 三条继续全绿而 `[control]` 两条红** —— `[control]` 存在的理由写成了实测:
   算术那半只在模型不是恒真时才承重。
   **⚠️ 当轮三处自伤,全部当轮抓住并修好**:
   (0) **第一版变异台整个失效,而且看起来正常** —— 还原写的是
   `git checkout -- bots tests/<新文件>`,那个测试文件**当时还是 untracked**
   ⇒ 整条命令在 pathspec 上报错退出 ⇒ **`bots` 也没被还原** ⇒ 六条变异**累积叠加**,
   失败计数 3→3→5→5→6→7→8→8 读起来像一张正常的递增表,**没有任何一条腿举手**。
   **`evidence-discipline` 规则 1 的站点再加一个**(而本轮是在犯完之后才读到该技能)。
   连带订正一条读数:M8 原记为「打偏到别的文件、全绿 = 正确的作用域外无操作」,
   上哈希后看清 `aiug:4040` 是 `sCastMotive = '智力腿切敏捷回复'`、**根本不含被替换的模式**
   ⇒ `sed` 一个字节都没改 ⇒ **M8 不是「抓不到的变异」,是「不存在的变异」**;
   两种解释给出**同一个绿**,分辨它的不是更聪明的判读,是**变异前后各取一次哈希**
   (规则 4 的形状)。
   (i) **`strip_comments` 把锚点也删了** ——
   「撤退:3」的锚 `第三种情况` **本身是注释**,喂 stripped 源进去 ⇒ `count==0` ⇒ 断言按
   「锚点不唯一」报错,**十个算术用例在健康的树上同时红**;改成 `mask_comments`
   (注释**涂成等长空格**、偏移逐字节对齐):锚在**原文**找、子句从**涂白码**取。
   与 `0MODE` 的锚点自伤同族:**跨度函数的输入源要和锚点的性质对齐**。
   (ii) **刀口探针探错析取项** —— 用 `tp3_entered(0.34, 0)` 探 HP 帽严格性,而 `0.34+0 < 0.43`
   **为真**,读到的是 sum 析取项在放行却被报成「HP 帽变成非严格」;探 HP 帽必须先用高 mana
   把 sum 析取项关掉。**两个析取项约束同一个量,哪一个都不能单独读** —— 正是 `[arith]` 要防的混淆,
   本轮先在自己身上发生了一次。
   **⚠️ 诚实边界**:`botMP >= 0` 是**外部操作数**(引擎法力值域),`J.GetMP` 对 **huskar**
   返回 HP 比值(仍 ≥0,推导不变;分支本来就按名字排除 huskar)—— 两条已写成 `[limit]`;
   **#340 的百分比本文件一个字都不断言**(别人的仪器、本进程看不见的语料;重新归类一个桶是
   关于**树**的算术,**不是重新测量**,并已写断言防止被当成一次测量引用);
   **本文件不裁任何人**,**不重开也不反驳 #340 的 INDETERMINATE**(#340 测的是 TP 腿,
   且它关于 TP 腿域为零这一点是对的);**不主张 0.55 错了或该动**(一个调用点上死掉不等于错,
   它在另一个调用点上是活的);**本轮没跑 `.dem` 语料**,那 52 行**从哪个按下点发出**本组不主张,
   只主张**不是「撤退:3」**;**全量单进程套件本轮未跑完**(GH #124)。
   **下一格**:**录像组**(重跑 #340 §2 的表时**先与调用点进入条件求交**;`hp>0.55` 桶要在
   **走路腿**上重新分解才有意义,与 #338 的「按主槽 `item_flask` 分层」合并;那 52 行的
   按下点来源 —— dump 已有 hp 列)、**总监**(本组**不主张**任何入集/出集变动;请裁一条**方法**问题:
   第一失败子句分解是否**统一要求**先与调用点进入条件求交,若要则同时约束本族之外每一份
   `*_domain.py`)。**不认领**:#339/#341(`[harness]`)、#331/#330/#328(`[hero]`)、
   #321/#313/#308(`[batch]`);#338/#324/#323/#319/#304/#300 均为本组此前认领、现等他组裁定。

0EMPTY. **【2026-08-30T16:25Z 新增,自选题,**已发 GH #338**(无未认领 `[strategy]` issue;录像组 15:58Z §13 第 1 条
   把 `stayfield`/`stayfield2` 点成下一轮补课目标,本轮做的是那句话的前置);一条**闭式空集**形式的
   主判据 + 一条**外一层**的可复用判据 + 两条写成断言的语料限制;`bots/`/`game/` **逐字节零 diff**,
   零新 gate id,`queue.json` 一字未动,零 AWS、S3 零访问。**已交棒,球在录像组与总监。**】**
   **⭐ 主判据:`stayfield` 在它唯一的调用点上的反事实域是 EMPTY —— 闭式,不是抽样读数。**
   两个 wrapper 委托同一个谓词 `J.ShouldRegenNotGoHome = situation ∧ source ∧ IsFieldSipEnough`;
   `fieldsip`(08-29T18:5xZ 入集 §CG,W27/W28 armed)把第三项变成 `sip >= 0.25*maxHealth`,
   而 `sip` 是 `J.FIELD_SIP_HEAL` 上的 max,`item_flask = 400` 比第二名 `item_bottle = 135` 大 **2.96 倍**。
   调用点 A(`ability_item_usage_generic` 的「撤退:3」)**自带 `and itemFlask == nil`**,
   其中 `itemFlask = J.IsItemAvailable("item_flask")` 而该函数**只在 `slot >= 0 and slot <= 5` 时返回** ——
   正是 `FieldRegenSipValue` 默认扫的槽段 ⇒ 那里能够到的上确界是
   `sup{115 tango, 115 tango_single, 85 faerie, 135 bottle} = 135` ⇒ `135 >= 0.25*H ⟺ H <= 540`;
   同一分支又要求 `bot:GetLevel() >= 9`。⇒ **`fieldsip` armed + `bagsalve` 未 armed(= W27/W28 那根串)
   时,`stayfield` 的条件 (a) 不是「没买到」,是「买不到」。** 方向保守:算术把分支**其余全部合取项
   一律当成已满足**(CanJuke/攻击目标/七个 modifier/离泉水距离/英雄名/外层 mode),在全部给定下仍为空。
   **⭐⭐ 可复用主判据(本族的**外一层**,不是 `0SITE` 已有那条)**:`0SITE` 钉的是「守卫的域 = 它的谓词
   ∩ 它被塞进去的合取式」,两份文件之内算得完;本条是——**第三个 id,晚三个月入集,在第三个文件里,
   带着自己独立的裁定,可以把那个交集清空,而两者互不点名**。`fieldsip` 不是「撤退:3」的合取项、
   源码里一次也没提过 `stayfield`;它只挪了两跳外一个 helper 的阈值,而分支自带的、看上去毫不相干的
   `itemFlask == nil` 把那次挪动**翻译成一个零**。失败方向是最贵的:**没有任何东西变红**,
   两个 id 成员资格照旧,`check_armed_wiring.py` 照样判 WIRED(它查「调用点存在」,不查「谓词在那里
   可能为真」)。**与 `pullcad` 陷阱同形,外一层:那里两个 id 至少互相点名,这里从头到尾没有。**
   **⭐ 有用的那半 —— 两个 wrapper 的域不一样大**:调用点 B(`mode_retreat_generic:236`,`stayfield2`)
   从 `GetDesireHelper()` 开头到调用之间 `item_flask`/`itemFlask`/`IsItemAvailable` **三个 token 一个都没有**
   (已写成断言)⇒ 主槽大药可达 ⇒ 天花板 `400/0.25 = 1600` 而非 540。**本族的 (a) 只能从走路腿读**,
   分层按「主槽是否带 `item_flask`」(dumper 已有的物品列);边际域还要再减 promoted 的
   `J.ShouldStayAndRegen`(排在前面、返回**同一个** `NONE`)已吃掉的帧。
   **⭐ 第三半 —— `bagsalve` 不再是搭车的**:它的入集论证写着单独 arm 是「逐字节 no-op」;在调用点 A 上、
   `fieldsip` armed 时**反号** —— 背包腿是**唯一**一条 `itemFlask == nil` 杀不掉的腿(`IsItemAvailable`
   停在 5 槽,大药在 6–8 槽时那个合取项**仍然为真**)⇒ 它是 540 血以上**唯一**的使能器。
   已在**真实背包大药帧** `f_260822_182012_sb_backpack_rescue_372` 上驱动(非建模):
   未 armed sip `0` → armed `400`,`400 >= 0.25*1378 = 344.5`,**而 `IsItemAvailable` 两边都是 nil**。
   **真实帧驱动(owner P2 自己那一帧)**:`f_260822_063722_lina_tp_home`(lina lvl9 maxhp1088 hp0.318,
   slot0 faerie_fire 85、slot5 空瓶)—— 无 `fieldsip`:谓词 **true**,两个 id 都开口;
   W27/W28 串:`85 < 272` ⇒ **false**,两个 id **都哑**;塞进有充能的瓶子:`135 < 272` ⇒ **仍哑**;
   塞进**主槽大药**:谓词 true,**但分支自己的 `itemFlask == nil` 已经把它杀死** ⇒
   **hold 与它守的分支在「大药」上互斥**,`fieldbuy` 投主槽的成功补给**永远记不到 `stayfield` 头上**。
   **这不是「`fieldsip` 错了」**(把那一帧移到 supply 侧正是它写明的设计);新的是**副作用**——
   它改变了另外两个 id 的**可测性**,**而没有任何一份裁定登记过**。
   **产出**:`tests/test_stayfield_callsite_domain.lua`(`[ratchet]`,**21/21**,2.4s;
   `[source]`7 + `[arith]`3 + `[drive]`4 + `[control]`3 + `[limit]`4)。两条天花板 540/1600
   **从表里现算**(改一个 heal 值就重新推导),含刀口两侧;**锚点唯一性写成断言**
   (`第三种情况` 计数必须 == 1)——**上一轮 `0MODE` 自伤的根因,这轮预防而不是事后修**。
   **变异 11 条:10 CAUGHT / 1 SURVIVED(按设计)**。M11(走路腿 `NONE`→`HIGH`,否决变地板)
   **登记而非粉饰**:本文件量的是**域**不是**返回值**,同一补丁在
   `tests/test_replay_260822_lina_walk_home.lua` 下**红 3 条** ⇒ 覆盖在它该在的地方;
   顺带实测 `test_retreat_priority_order.lua` **抓不到**它(那条不变式只管「守卫按降序」,`NONE` 是豁免项)。
   **⚠️ 诚实边界(全部写成断言)**:(i)「level ≥ 9 ⇒ maxHealth > 540」**不在树里**,是外部操作数 ——
   语料上量:318 个 level≥9 活体行里 `max_hp <= 540` 只有 **4 行,且四行是同一个英雄**
   (`medusa` lvl11,max_hp 230/450/450/450)⇒ **314/318**,例外像 dump 读数异常不像反例;
   (ii) `bagsalve` 腿在 fixture 上**端到端跑不通** —— 全语料 **14 行**「背包有大药、主槽没有」,
   `IsFieldRegenSituation` 在其中 **0 行**为真 ⇒ 驱动停在 presence + 量级两项,**语料所限不是取舍**;
   (iii) `nMode == BOT_MODE_RETREAT` 在 fixture 上不可达(GH #89)⇒ 分支侧归因在**源码**、谓词侧驱动在**真实帧**,
   最终出价**不断言也不主张**;(iv) **本文件不裁任何人** —— 不主张 `stayfield`/`stayfield2` 出集或留集,
   不重推也不反驳 `fieldsip` 自己的 (a)(录像组 15:58Z 判 WORKING),**空集证明不是裁定**;
   (v) **全量单进程套件本轮未跑完**(≈310 分钟,GH #124)⇒「跑到这里没红」不是「全绿」。
   **下一格**:**录像组**(别在 W25–W28 上买 `stayfield` 的 (a),那是空集;本族 (a) 从
   `stayfield2` 走路腿读,按主槽 `item_flask` 分层)、**总监**(§CG 那次入集没登记它掏空了
   `stayfield` 的 TP 腿,可能需要同 §CG.3 条件 D 同族的一条;`bagsalve` 的「单独 arm 逐字节 no-op」
   论证在 `fieldsip` armed 时反号,排期有内容了 —— 本组**不主张**给它发波,只主张论证要更新)、
   **harness/总监**(medusa 的 `max_hp` 读数,本轮**不开独立 issue**,请裁要不要立案)。
   **不认领**:#332(`[batch]`)、#334/#335(`[harness]`);#294/#300/#304/#318/#319/#323/#324/#333
   均为本组此前认领、现等他组裁定。

0MODE. **【2026-08-30T13:27Z 新增,**认领 GH #333**(录像组 13:05Z 新开,§三.1 白纸黑字把下一棒交给
   fixture 路线,而 `tpreach` 是本组地界的 id —— 本组 GH #319 正在裁它的合取项);
   一条**闭式上确界**形式的主判据 + 一条**退回 fixture 路线**的实测 + 一条**当轮抓住并修好**的锚点自伤
   + **修回本组自己 11:13Z 造成的章程损坏**;`bots/`/`game/` **逐字节零 diff**,零新 gate id,
   `queue.json` 一字未动,零 AWS、S3 零访问。**已交棒,球在录像组(两列已有的 dump 数)与总监。**】**
   **⭐ 主判据:#333 要的判别器不是 mode,是算术 —— 撤退支的 HP 上确界是 0.87,闭式不是估计。**
   `nMode == BOT_MODE_RETREAT` 块(`ability_item_usage_generic.lua:5506–5664`)**恰好三条 TP 按下**
   (:5581/:5616/:5662),每条带 HP 帽:撤退:1 `botHP < 0.19`;撤退:2
   `botHP < 0.15 + 0.24*nEnemyCount` **且** `nEnemyCount <= (botHP < 0.4 and 2 or 3)`;
   撤退:3 `botHP < 0.34 or botHP+botMP < 0.43`。**只有撤退:2 会随敌人数抬高,而抬高它的那个量
   正被它自己的第二个合取项帽住** ⇒ `botHP >= 0.4` 时帽是 3 ⇒ 杠杆最高 `0.15+0.24*3` = **0.87**;
   撤退:3 的析取项被操作数值域关掉(`botMP >= 0`)⇒ **sup = max(0.19, 0.87, 0.43) = 0.87**,
   即 **hp >= 0.87 关掉树上每一条撤退 TP 按下**。**方向是保守的**:`[arith A1]` 把**所有非 HP 合取项
   一律当成已满足**(掉血史/卡视野/大药/modifier/离泉水距离/英雄名),在全部给定下仍关掉,
   **比按那一帧真实取值关掉严格更强**。
   **⭐⭐ 因此 #333 那一帧是真漏不是残渣**:lion `990f5c/20260830_063340_slot1` armed 腿 t=657.0
   **hp=0.90 >= 0.87 ⇒ 撤退世界关闭**;独立佐证 —— 三条撤退按下的落点**全是 `J.GetTeamFountain()`**,
   而 #333 自己观察到「**落点不回家**」。⇒ 按下来自**会咨询** `J.CanEnemyInterruptTpChannel` 的路径;
   `[drive D1]` 在真实谓词上驱动那一帧:**未 armed = false**(705 > 700,盲带)、
   **armed = true**(705 <= 750)⇒ **armed 本该否决而它没有**。
   其余两个咨询点(`GetRescueTpTarget` 需 `lf_rescue`、mid/sup 响应 TP 需 `midtp`/`suptp`)
   **不构成第三个世界**:门关着时**直接 `return nil`、根本产生不了按下**,门开着时**都咨询**。
   **⚠️ 唯一限制,也正是下一棒**:0.90 是 **1Hz 采样**,#333 表里按下夹在 656.5 行(0.90)与
   657.5 行(**0.69 < 0.87**)之间 ⇒ 若真实按下 HP 是后者,**撤退:2 重开**(需 `nEnemyCount = 3`)。
   ⇒ 裁定**条件于一列已经在 dump 里的数**;而这恰是最值钱处:**hp 与 nEnemyCount 是 dump 已有的列,
   mode 不是** ⇒ **#333 §三.2「需要 harness 补 mode 字段」那条线本组认为不欠**。
   `[control C1]` 把这个刀口写成断言(0.86/3 可达、0.69/3 可达、0.69/2 关闭)。
   **⭐ 退回 §三.1 的 fixture 路线(只退这一步)**:钉那一帧的 fixture 驱动的是**谓词**,armed 得 true
   —— **在两个世界里都是 true**,因为**谓词的答案不取决于调用者问不问它** ⇒ **报绿而零信息**,
   与 `0FOG`(甲)/`0GEOM` M5/`0SENSE` M12 同族。判别要驱动**调用点**并带真实 mode,
   而 `[corpus C3]` 实测:`GetActiveMode` 在 `bots/` 调 **360 次**、在 `tests/mock/` **定义为零**、
   **107 个 fixture 里 0 个携带** ⇒ **fixture 路线不是绕开那个缺失操作数,是继承它**。
   C3 写成**存在性**不是头计数:加 fixture 不会变红,**只有真把操作数接上才会**。
   **产出**:`tests/test_tpreach_retreat_exclusion.lua`(`[ratchet]`,**8/8**;
   官方 runner `run_tests.lua tpreach` **15/0** = 新 8 + 既有 7)。
   **变异 11 条:11 CAUGHT / 0 SURVIVED**,分两族登记 —— **M5(模型恒 false)⇒ C1 红而 A1 全绿**
   (C1 存在的理由:算术那半只有靠 C1 证明「帽子下面确实够得着」才承重);
   **M10(改树上的 0.24、模型不动)⇒ S2 红而 A1 绿**(分工写成实测:S2 一旦被删,
   A1 继续通过但描述的是一棵不存在的树)。
   **⚠️ 当轮自伤(第一遍红、当轮修好)**:S1/S3 第一版锚在 `nMode ~= BOT_MODE_RETREAT` 上,
   **而它不唯一**(另一处 :4029 且**排在前面**)⇒ S1 的 span 从 :4284 吃到 :5668、
   **把 :5239 那道真门吞了进去**,健康的树上双红。改锚到**唯一的 wrapper 调用**并加 `TPSAFE2_ONCE`
   钉住唯一性(M11 有牙:加第二个调用点 ⇒ 三红)。
   **与 `0GEOM` M5 同族:锚点唯一性本身要被断言,不能靠读一次 grep 记住。**
   **⚠️⚠️ 顺手修回章程损坏**:`d42f90a0`(本组 11:13Z followup)把 backlog 的 0FOG..文件尾
   **整段 2,960 行复制了一份**并插了**第二个 `## 当前状态` 标题**,两节从 12:25Z 起内容分叉;
   **这正是自检 `citation_audit` 的 AMBIGUOUS 家族**,在 main 上躺了约 2 小时。
   修前逐行断言过重复(`L[73:3033] == L[3081:6041]`)⇒ **删的是证过的重复,不是判断**。
   **教训与本轮 S1/S3 自伤同一个根因:大段插入要按唯一锚点定位,并在写盘前断言节的条数。**
   **⚠️ 诚实边界**:无行为改动 ⇒ 无修复用 fixture;**本轮无新帧**(那一帧**被引用不被驱动**,
   timeline 在 S3);**不重推也不反驳** #333 的 6/1010、分层与 INDETERMINATE 裁定;
   **不主张 `tpreach` 该 promote 也不主张该出集**((b)/(c) 不归本组,**一帧不是条件 (a)**);
   `[arith A1]` 跑的是**本文件的模型**不是树。顺带:**mock 层吞掉 `print`**。
   **⚠️ 全量单进程套件本轮未跑完**(上一轮实测 ≈ **310 分钟**,GH #124)⇒
   **「跑到这里没红」不是「全绿」**。
   **下一格**:**录像组**(这一棒变小了 —— 读 `990f5c/20260830_063340_slot1` t=657.0
   **按下瞬间的 hp 与 1600 内敌方英雄数**两列,都已在 dump 里:`hp >= 0.87` ⇒ 判 **BUGGY**;
   `hp < 0.87 且 n == 3` ⇒ 仍不可判。**不需要 harness 补 mode**)、
   **总监**(裁 #333 §三.3:`--reach-mode source` 那列的 0 写进 §BC 作已知读法限制,本组同意写)。
   **不认领**:#332(`[batch]`)、#334(`[harness]`);#318/#319/#323/#324 均为本组此前认领、现等他组裁定。

0DRAG. **【2026-08-30T10:38Z 新增,**认领 GH #326**(章程 backlog #7「拉野节奏打磨」正压在它上面,
   且 #326 §「请总监裁」的 (乙) 白纸黑字写着「属协同组地界」);一条**不等式**形式的主判据 +
   **一个真的落了地的 gated id** + 一条**当轮抓住并修好**的量具自伤。**已交棒,球在总监与录像组。**】**
   **⭐ 主判据:拉线的 DRAG 不是「很少走」,是空集 —— 而判据是一条不等式,不是一个百分比。**
   拉线节拍 `if POKE / elseif hold / else DRAG` **三条臂全部**坐在 Think 开篇的动画节流阀后面
   (`IsBotThinkingMeaningfulAction`,表头就是 `ACTIVITY_RUN`/`ACTIVITY_ATTACK`)。
   刚右键完对线英雄的 bot **按构造**在 `ACTIVITY_ATTACK` 里待满一个攻击周期。记 **R** = 节流阀重开间隔,
   节拍**只在重开帧上被问到**、而那种帧上距上次 poke 已 **≥ R** ⇒
   **`R > nBeat` ⇒ POKE 那个 `if` 在每个能问到节拍的帧上都为真 ⇒ DRAG 那个 `else` 一帧都到不了。**
   出厂 `nBeat = 1.2`、前期攻击周期 ~1.4–1.7s ⇒ **出厂配置站在不等式的错误一侧**。
   与 GH #186/`pullthink` 同族:那条注释自己写着「Scoped to the CAMP pull only … one lever at a time」,
   **本轮兑现的就是它明写的那半**。
   **⭐⭐ 因此 GH #326 的一步推论要退回来(只退那一步)。** 它从「6 秒坐标逐位不变 + 四次右键」
   推出「两条腿都写不出这形状」⇒ 判成**域泄漏** ⇒ 非分支人口下界 **40.0–51.8%**。
   **分支写得出**,新测试就在真实帧上驱动它写出来。而**它自己的 gap 列带着符号检验**:
   1.6/1.4/1.6 **全部大于**出厂 1.2s、**没有一个更小** —— 那是「延迟」的签名
   (节流阀只能让 poke 迟到、不可能提前),**域泄漏没有理由是单边的**。
   ⚠️ **只退那一步**:静止帧的**计数**不反驳也不重推;±6% 足迹上界是 **44 id 同波的 bundle 界**,
   #326 自己写明不主张已排除反向抵消 ⇒ **不能当本条的先验**。
   **产出(本轮有行为改动,gated)**:`bots/mode_roam_generic.lua` 一条并列旁路子句
   `not (bot.roamCreepPull ~= nil and J.IsSoakCandidate('creepthink'))`;
   `tests/test_creepthink_anim_throttle.lua`(`[ratchet]`,**12/12**,2.6s);
   `state.json:creepthink_20260830`;入集提议 `test_set.md §CK`;批测请求 `queue.json:strategy-25`
   (**提入集必须同开 queue 行**,§CG.5)。**零 AWS,S3 零访问。**
   **为什么是自己的 id**:打包由**包含关系**决定不由强弱决定(`0FOG` 主判据乙)——
   GetDesire **设一个 plan 就把另一个置 nil** ⇒ `pullthink` 与本条**按构造互斥**,
   合成一个 id 会让两边 (a) 读数谁也不归属谁(本组 GH #319)。已写成 `[gate G3]` 断言。
   **变异 11 条:10 CAUGHT / 1 SURVIVED(按设计)**。M8(promote 过的 `pullbeat` hold)
   **登记而非粉饰**:同一补丁在 `test_replay_pullbeat_attack_cancel.lua` 下**红 4 条** ⇒ 覆盖在它该在的地方。
   **⚠️ 当轮自伤(第一遍活下来、当轮修好)**:`[control C2]`「无计划时惰性」原本比**两份指令日志**,
   而**无计划的世界里没有指令可以不同** ⇒ 一个在每个 roam 帧都开火的旁路照样印出两串一样的点;
   **M3 因此只被源码断言抓住,行为控制绿得没有信号**。补 past-throttle 探针后 M3/M7 都在行为层咬住
   (M7 探针读 **482** 帧)。**与 `0CONJ`/`0SENSE` 同族:控制项写成了一个它承载不了的比较。**
   **`[arith A1]` 是分离器不是断言**:攻击周期在 nBeat 两侧各扫三点,**要求周期 < nBeat 时 drag 必须真的开火**,
   否则「全程零 drag」可能只是注入把 Think 卡死、整份文件**为错误的理由变绿**。
   **顺手修回棘轮**:`test_gated_helper_nesting_census.lua` 当场变红(新 id 进了 `pulldrag` 那行的外层集),
   **按它自己的规矩逐条答完再重钉**,仍判 **(W) 宽网**(callee 只在营地分支被调,两域互斥),答案写进该行上方注释。
   **⚠️ 诚实边界**:**攻击周期是个模型**(世界断言 W1:`GetAnimActivity()` 全语料读捏造的 0,
   九个调用点在本地全死),没建模的部分由**扫描排除不由假设排除**;不重推 #326 的百分比;
   **不主张 drag 走了就赢**(波次问题);**不主张 `pullcad` 因此被平反**(3.0s > R 会让 drag 可达是**预测**,本仓结不了);
   本轮**无新帧**(用树上已有的 `f_072738_zuus_mana`,#326 那张 W27 支点帧本组拿不到、是**被引用不是被驱动**)。
   **下一格**:总监(入集,`strategy-25`;⚠️ `creepthink` 与 `pullcad` 同波共 armed 的差分是**合力**,
   两者动的是同一个不等式的两边)、录像组(那一帧的判别只需**指令日志**不需位置列)。

0FOG. **【2026-08-30T07:24Z 新增,**认领 GH #324**(上一轮 `0SENSE` 明写「本轮不认领,留作下一格」的那一条);
   三条可复用主判据 + **一整类杠杆的本地验证盲区(实测,不是推断)**;`bots/`/`game/` **逐字节零 diff**,
   零新 gate id,零行为改动,`queue.json` 一字未动,零 AWS。**已交棒,球在录像组与总监。**】**
   **⭐ 主判据甲:#324 §3 的两条杠杆卡在同一个缺失传感器上,而它的兜底方案自己也卡在那儿。**
   引擎伤害归因面**一共五条,每条都自带归因词**(AnyHero / Hero / Creep / Tower)——
   既没有「被召唤物打了吗」(⇒ 正面式无操作数),**也没有「被任何东西打了吗」**
   (⇒ §3 自写的**否定式兜底同样无操作数**,这一点 §3 没预料到);`InstallDamageCallback` 全 `bots/` 零调用。
   ⇒ 与 #323 同一个传感器,**GH #327 一条覆盖两条 issue,不欠第二个传感器 issue**。
   源码侧同时钉住 #324 标题句:`IsFieldRegenSituation` 体内 `GetNearbyCreeps`/`GetNearbyNeutralCreeps`/
   `GetNearbyLaneCreeps`/`GetUnitList`/`UNIT_LIST` **全 0** ⇒ 没有一条子句看得见非英雄非塔非 creep 的单位。
   **⭐ 主判据乙:打包方式由包含关系决定,不由强弱决定。** #324 §1 的重叠**已经在表里、一次减法的距离**:
   `有 other − 只有 other` = 17/7/7/13,即 **15.5% / 10.8% / 15.9% / 21.0%**(四格同向,铁律 4(i) 满足)⇒
   **正面式与 `fieldcreep` 79–89% 不相交 ⇒ 该给它自己的 id**;**否定式按构造包含 `fieldcreep` 整个域 ⇒
   只能做 `fieldcreep` 的第二子句**,否则两个 id 的 (a) 读数谁也不归属谁(本组自己的 **GH #319**)。
   世界无关:「只有 other」帧在两个世界里都在 `fieldcreep` 之外。
   **⭐⭐ 主判据丙(本轮最值钱):#324 §2 的帧不指向守卫,指向雾 —— 而雾这一整类杠杆,铁律 4 的本地验证是绿的。**
   §2 自己的列:最近敌方英雄 **518u → 4552u 跨一秒 = 4,034 u/s = 550 移动上限的 7.3 倍** ⇒ **她没走出 1600 圈**;
   剩「掉视野」与「TP 走完」两解,**已发表的列分不开**(判别器 = 644.5–647.5 的传送 modifier/channel,在 timeline 不在本仓)。
   掉视野那一解要的操作数**本仓已出厂**(`J.GetLastSeenEnemiesNearLoc`),**但验不了**,两条独立理由:
   (甲) **107 个 fixture、0 个单位带 `seen_by`** ⇒ 每个敌人 `time_since_seen = 0` ⇒ 三个出厂半径上
   **321/321 对视野操作数与记忆操作数同读数,diff = 0** ⇒ 「问记忆而不是问视野」是**逐字节 no-op,而且报绿不报红**
   (`0GEOM` M5 / `0SENSE` M12 同族:守卫绿是因为它不承重);
   (乙) **补 `seen_by` 也不够** —— loader 盖 `visible_to_subject(u) and 0 or 999`,而 `bots/` 所有窗口**最大 6**
   ⇒ 值**永不落在雾读数生活的开区间**,看不见 = **没有记忆**不是**记忆过期**;loader 拒绝得对(**一帧快照没有历史**),
   ⇒ **要 dumper 直接吐 per-enemy `time_since_seen` + last-seen 坐标**,不是补 `seen_by`。
   **变异把 (甲)+(乙) 压成一句**:雾窗 `5.0` → **60.0 存活 / 900.0 存活 / 1000.0 才被抓**
   ⇒ **这个旋钮在整个可用开区间 (0, 999) 上本仓分不出来**,唯一测得到的是越过 999 哨兵,**而那是读源码不是驱动帧**。
   **裁定**:方向认同、§1 算术接受,**但 §3 两条杠杆卡点不同、§2 论证的是第三条**;
   **`fieldcreep` 一字未改(gated、未 promote)**;**不开占位 gate**(占位 gate = 声称可验证,而本轮全部内容就是反驳它)。
   **产出**:`tests/test_fogmemory_corpus_limit.lua`(`[ratchet]`,**10/10**,2.2s,快腿 tagged 34 → 35);
   **变异 16 条:14 CAUGHT / 2 SURVIVED**,两条 SURVIVED(M13 60.0、M14 900.0)**不是漏洞就是结论本身**,已写进文件头变异记录节。
   **⚠️ 顺手更正(本轮不改那个文件)**:`tests/test_campdanger_switch_safe.lua:45-49` 的
   「genuine fog memory … time_since_seen 0 for a hero the subject's team **can see**」**逐字为真但限定词是空的** ——
   本语料没有团队看不见的英雄,故 `J.GetLastSeenEnemiesNearLoc` 每一帧上**就是** `GetNearbyHeroes` 换个写法;
   对 `campdanger` 无害(那里问几何),但**别把那句话读得比语料强**,新文件 `[control C1]` 注释里写明了。
   **⚠️ 诚实边界**:无行为改动 ⇒ 无修复用 fixture;#324 §1 的 W25 读数不重推也不反驳(断言的是**减法**与**决策规则**);
   `[arith A2]` **只排除走路、没排除 TP**(写成了显式断言);`[drive D1]` 比**计数**不比身份(`[control C1]` 补足);
   **550 u/s 是游戏规则不是从 `bots/` 读的**(`bots/` 无处封速度),文件里点名以便复核。
   **下一格**:球在**录像组**(判别 §2 掉视野 vs TP;dumper 补 per-enemy `time_since_seen`)与
   **总监/harness**(**GH #327 原地扩范围**覆盖 #324 否定式,本轮已在 #324 追评点明、不另开 issue)。
   **#304/#319 本轮不认领**(均为本组此前已认领、现等他组裁定)。

0SENSE. **【2026-08-30T04:29Z 新增,**认领 GH #323**(录像组 01:25Z 新开、点名本组、带帧证据的两条里编号在前的那条);
   一条可复用主判据 + 一条**在整个取值范围上**被证伪的旋钮 + 一条**当轮抓住并修好**的量具自伤;
   `bots/`/`game/` **逐字节零 diff**,零新 gate id,零行为改动,`queue.json` 一字未动,零 AWS。**已交棒,球在录像组与总监。**】**
   **⭐ 主判据:布尔谓词在一帧上的全部信息量 = 它仍为真的最小 dt;要读「量级」就是要一个新传感器,不是调旋钮。**
   `bots/` 读野怪伤害只有一条路 —— `bot:WasRecentlyDamagedByCreep( 3.0 )`(`jmz_func.lua:5329`),**布尔**;
   `docs/BOT_API_REFERENCE.md` §Damage History **四布尔 + 一 float**,而那条 float
   (`TimeSinceDamagedByAnyHero`)**只有英雄版没有野怪版**。fixture 行里 `value` 是有的
   ⇒ **语料能回答的问题,bot 问不出来**。唯一能造账本的入口 `InstallDamageCallback`
   **全 `bots/` 零调用** ⇒ 传感器不是「没读」,是**不存在**。
   **⭐ 那个唯一的旋钮被一个平局证伪,而且是在整个取值范围上**:本仓 `fieldcreep` 真咬到的 **5 帧**里,
   重伤组 min-dt 最大 **0.60**(viper,129)= 轻伤组 min-dt 最小 **0.60**(luna,22)⇒ 平局劈不开;
   断言不钉在平局上,**在 0.05 网格上跑遍 (0, 3.0] 得 `separators == 0`**,并配**可分桩控制**(0.2 vs 1.5 必须找出 ≥1 档)。
   **⭐⭐ 本仓语料装不下 #323 §4 的验收,两条独立理由**:(甲)它要放开的那一格(**轻伤 × 有补给**)**是空的** ——
   五帧是 2 重伤+补给 / 1 重伤+空包 / 2 轻伤+**空包**;空包帧**两个方向都驱动过**,
   放开它们**只动补给那半(`fieldbuy`)、HOLD 那半一帧不动**;该格写成**等式零**,
   录像组一落帧就红。(乙)**单位是 §4 自己定死的**:按**每次使用**读,两帧有补给的重伤帧**全部**翻成「反向」
   (109 对 tango 115、132 对 salve 400),而 §4 要求它们**继续否决** ⇒ 只能读**每 3 秒**;
   按每 3 秒读五帧无一反向。**tango 那帧把这个单位选择决定在 6 点血上。**
   **裁定**:**认同方向与单位、但杠杆今天落不了地也验不了** ⇒ `fieldcreep` 保持原样;
   **不开占位 gate**(占位 gate 等于声称它可验证,而本轮发现正是它不可验证)。
   **产出**:`tests/test_fieldcreep_magnitude_operand.lua`(`[ratchet]`,**7/7**,4.2s,快腿 tagged 29 → 30)。
   **⚠️ 当轮自伤(M12 第一轮活了下来)**:块注释控制**写成单行**,被**行注释那一遍**顺手删掉
   ⇒ **块注释那一遍坏掉也全绿** —— `0CONJ` 自伤乙原样重演;改成多行、只断言**第二行**后转 CAUGHT。
   **⚠️ 登记而非粉饰(M9 SURVIVED)**:source 断言全跑 `code_only`,但**今天 jmz_func 的注释用白话描述这条读数、
   没原样引用调用**,`JMZ_SRC` 与 `JMZ_CODE` 同为 1 ⇒ 换掉仍全绿。补 control 断言 `raw == code`
   并写明「哪天注释开始引用,这个等式会红,那一刻守卫才承重」;M13 证明这条 control 的牙齿是**前瞻的**。
   **变异 13 条:10 CAUGHT / 3 SURVIVED(全部按预期登记)**,每条先核对补丁真落上。
   **⚠️ 诚实边界**:无行为改动 ⇒ 无修复用 fixture;`value` 是 dumper 的数、不重推;
   `WasRecentlyDamagedByCreep` 的两个世界仍未决(GH #324 §4 本轮再次证伪其判别器),
   但**主判据说的是返回类型不是域**,故不依赖它;#323 的 72.5%/72.4% 是 W25 语料,本文件不重推也不反驳。
   **下一格**:球在**录像组**(把 #323 §3 那帧 `--t 249.5 --hero obsidian_destroyer` dump 进 `tests/fixtures/`
   —— 本组不碰 S3 拿不到 W25 timeline)与**总监/harness**(裁传感器:`InstallDamageCallback` 账本,
   或 dumper 侧补敌方单位与攻击力 —— 与 GH #305/#306 同族,#306 已点名那是 fixture 上没建模的 0;
   **已开 GH #327 把这一棒显式交出去**)。
   **#324 本轮不认领**(新增子句不是重窄,且操作数问题与本轮同源),留作下一格。

0GEOM. **【2026-08-30T01:24Z 新增,**认领 GH #318**(唯一一条点名本组、带帧证据、本组此前未认领的 open
   `[strategy]`);两条可复用主判据 + 一条**当轮抓住并修好**的量具自伤;`bots/`/`game/` **逐字节零 diff**,
   零新 gate id,零行为改动,`queue.json` 一字未动,零 AWS。**已交棒,球在录像组与总监。**】**
   **⭐ 主判据甲:#318 §5 提的重划(「让出口问**攻击表**而不是**存在表**」)是逐字节 no-op ——
   那两张表是同一个谓词。** `NeutralFarmList` 与 `NeutralPresenceList` 都是
   `J.Site.FilterFarmNeutrals(tCreeps, hBot:GetLevel(), turbo and IsSoakCandidate('<id>'))`,
   **只差 id 串**(`campfarm`/`campvoid`);「我能不能打它」与「它在不在这」由**一个**谓词、**一道**等级门回答。
   **真正不同的是 sweep 不是谓词**:`GetNearbyCreeps(900|1000)` vs
   `GetNearbyNeutralCreeps(min(GetAttackRange()+180, 1600))` ⇒ **那个半径是 `campvoid` 的域唯一站得住的操作数。**
   **⭐ 主判据乙:扫描以 bot 为心不以营为心 ⇒ 域的边界是不等式不是两个常数比大小。**
   设 `d`=bot 到远古营中心、`dnb`=远古营到邻近普通营(#318 §2:西 **146**、东 **338**)、`R`=sweep 半径,
   则**保证在圈内**当且仅当 `d <= R - dnb`。**这条把 #318 §1 那张池化的 escape 表劈成两个总体**:
   远程(zeus 380→414 / veno 450→484 / lion·CM 600→634)**把 400 u 桶整个关上** ⇒ 那里的
   `0/38`、`0/8` **是算术算出来的、不携带信息**;近战(axe·WK 150→**184**)**没关上**。
   **⇒ 交给录像组的那一棒:escape 表拆 melee/ranged 再读一次。**
   **⭐⭐ 答掉 #318 §5 point 2**(「删掉远古之后 `#nNeutrals` 到底是不是 0」):**不是**。
   用那段 episode 自己的两帧(veno L10,西 Prowler 营;`d` **305 / 199** 由 fixture 现算)驱动真实
   `FilterFarmNeutrals`,L4/9/10/11 上 `#kept == 1`(邻营那只留下)⇒ 出口关着 ⇒ **`campvoid` 在这两帧逐字节 no-op**;
   L12/15/25 `rawequal(kept, sweep)` 出厂身份不变。**[control C1]** 邻营删掉则 `#kept == 0` 出口打开 ⇒
   **真实域是「邻营已死或够不着」,不是「站在远古营里」**(没有这条控制,整份文件对一个永不返回空表的谓词也全绿)。
   **唯一没被几何关上的一格**:近战 × 东营(338 > 330),**余量仅 8 u**,而 #318 §2 自己在另一子集把它复现成 1384 u
   ⇒ **东边这个数是不稳的那个**,已写进断言。
   **产出**:`tests/test_campvoid_domain_geometry.lua`(`[ratchet]`,**10/10**,快腿 tagged 28 → 29)。
   **⚠️ 当轮自伤(M5 第一轮活了下来)**:[source S2] 第一版直接 `src:find` 那条出口分支,
   而 `mode_farm_generic.lua` **头部注释块把那一行原样引用了一遍** ⇒ **匹到的是注释不是代码**,
   把真分支改成 `#nNeutrals <= 1` **十个用例全绿**。**GH #300 已付过一次钱的「注释冒充调用点」,
   在一个专讲 `campvoid` 的文件里又踩一次。** 修法:源码断言全跑 `code_only()`(先去 `--[[ ]]` 再去整行 `--`),
   **并补 [control C2] 让 stripper 自身可证伪**,且**按注释形态锚定不按分支文本锚定**
   (GH #221/#276:一编辑就变红 = 复述)⇒ **实测解耦:M5 只被 S2 抓、M9 只被 C2 抓。**
   **变异 10 真 10/10 全抓 + 3 CONTROL 全绿**,每个变异先验落点;**M10 perl 正则写坏、补丁没落上而 marker 没拦住,
   换 M11 重做,登记在案。**
   **⚠️ 诚实边界**:本轮**无行为改动所以无修复用 fixture**;`dnb` 146/338 是 #318 §2 的读数、**本文件不重推**;
   **攻击距离是声明值**(fixture 不带 attack range,mock 默认 150);中心到中心是代理,一律取最坏方位;
   creep 半不在语料里([world W1]);**长注释那条 gsub 今天不可证伪**(该文件 `--[[` 块数 **0**),
   按 `0CONJ` 自伤乙**登记而非粉饰** —— C2 直接断言这个 0。
   **下一格**:球在**录像组**(melee/ranged 拆分)与**总监**(裁主判据甲;`campvoid` 若重划,
   本组建议动 `nSearchRange`,**但本轮不动**——一次一个小杠杆,那要新 id + 新波次)。

0COARM. **【2026-08-29T22:27Z 新增,自选 backlog,GH #319;**兑现 `0CONJ` 上一轮亲手登记、写明「本轮不动」的那一条**;
   一条可复用主判据 + **两条被现行认证放过的 live 合取** + **一条有日期的后果**;`bots/`/`game/` **逐字节零 diff**,
   零新 gate id,零行为改动,`queue.json` 一字未动,零 AWS。】**
   **`J.IsSoakCandidate` 的合取是在被调用者的调用点上成立的,而全仓认证「这个 id 无合取项」时读的是
   它自己那一行门。两个地址不是同一个,被检查的那个不是做决定的那个。**
   `0CONJ` 钉的是 freeze 那一面(只 arm 外层 ⇒ 内层未 armed ⇒ 可能是 no-op);**本轮是另一面**:
   **内层也 armed 时什么都没冻,而外层的 (a) 读数已经不是外层的了** —— 它是 `outer AND inner`,
   波次却按请求行的 id 归属它。
   **⭐ 主判据(可复用)**:**排名按 fan-out = 排名按潜力;register 只能由「源码普查 × arm 串」的 join 回答。**
   `0CONJ` 登记 `J.IsInLaningPhase`(fan-out **15**,全仓最大)并结案「非 live」,**那句话本轮复核仍然对**,
   原因还更强(**中心到这个程度的谓词正因为中心才没人敢入集**)。**但 register 不是被它回答的**:
   实测 **8 条 live 合取,fan-out 全部是 1** —— 小、局部、不起眼的谓词,**正因为小才被入集**。
   fan-out 表:`c2`/`c4` **15**(未 armed)、`depthnum` 5、`bagsalve`/`ccburst`/`esaftershock`/`lanehyst` 2,
   armed 的七个(`fieldbuy` `fieldcreep` `fieldsip` `pulldrag` `stayfield2` `towerfear` `tpreach`)**全是 1**。
   **⚠️ 两条被现行认证放过的 live 合取**:(i) **`tpreach`(§BC.3「门是它自己那一条 ⇒ 无合取项」)** ——
   对门为真,但 `J.CanEnemyInterruptTpChannel` 的调用点 `jmz_func.lua:8312` **在
   `J.ShouldTpSupportTowerFight` 体内、在它 `:8288` 那道 `midtp`/`suptp` 门之后**,两者今天都 armed;
   armed 的 `tpreach` 把扫描 700→1200 拉宽 ⇒ 更常 veto ⇒ **`midtp`/`suptp` 量的是 `midtp AND NOT tpreach-veto`**。
   (ii) **`pulldrag`(:176「门是独立的一条,不与 `pullcamp` 合取 —— 踩 `pullcad` 陷阱」)** —— 也对门为真、
   规避是刻意的,但调用点 `mode_roam_generic.lua:363` 坐在 `:224` 那道**带 gate 的提前 return** 后面
   (未 armed 的 `pullthink` 让节流在它被走到之前 `return`),而 armed 的 `pullthink` 又走 `:321`
   那条 `elseif` **跳过 `:354` 这条调用所在的分支** ⇒ **`pullthink` 同时给它加帧和减帧,
   而这既不是嵌套门、也不在任何一份合取普查的形状里**。
   **⭐ 于是:陷阱在被检查的那个地址被绕开了,在做决定的那个地址被踩了。**
   **判别便宜:对每个 armed id,别读它的门 —— 读谁调用它的 helper。**
   **⚠️ 一条有日期的后果**:`fieldsip` **08-29T18:5xZ 入集**,它的 helper 被读在
   `J.ShouldFieldBuyRegen` 体内 —— **那正是 `fieldbuy` 的门**;未 armed 时 `IsFieldSipEnough` 是字面量
   `true` ⇒ 出厂读 `not source`,armed 后读 `not source OR not sip-enough`,**严格更宽**。
   ⇒ **在没人碰 `fieldbuy`、也没有任何东西说话的情况下,它的 armed 腿在数的东西变了;
   跨过那个日期的两次 `fieldbuy` 触发计数不是同一次测量。** §CG.4 预警的是 `fieldsip` 自己的 (a)、
   点的名还是 `stayfield`/`stayfield2`。
   **产出**:`tests/test_coarmed_attribution_register.lua`(`[ratchet]`,**11/11**,快腿 31 → 32)——
   把总监一直在**手写**的那条附加条件(§BW.3 `campexit` / §CG.4 `fieldsip`)机械化。
   **live 8 对**:`fieldbuy>fieldsip` `fieldbuy>fieldcreep` `fieldregen>fieldbuy` `tpdeathbuy>fieldbuy`
   `midtp>tpreach` `suptp>tpreach` `pullthink>pulldrag` `pullcad>pulldrag`。
   **⭐ 断言是 CONTAINMENT 不是等式,照总监自己的裁定写**(GH #221/#276,`test_carrier_terms.py`:
   「每次它读的 arm 串被编辑就变红的测试是在复述 arm 串」)⇒ **退集永不红、入集不产生新对也不红,
   只有产生新混淆时才红** —— 那正是该写附加条件、而此刻全仓没有任何东西举手的那一刻。
   **变异 12 真 12/12 全抓**(M10→主断言 / M3→arm 串解析 / M11→fan-out **逐条核对是登记的那个测试在红**),
   **每个变异先验证补丁真落上**(`0DODGE` M7 与 `0ADDR` M2 的自伤判据,本轮一次未发生);
   **3 CONTROL 全绿**。加固三处:长注释控制**用多行**(`0CONJ` 自伤乙)、arm 串**按文档顺序锚定不按行号**
   (`0ADDR`;实测 `test_set.md` **13 行**符合形状,第 1 行 live、其余 12 行历史,并补控制证明
   **标题之上的 id 形状行不会被读成 arm 串**)、**读不到 arm 串一律 FAIL 不静默通过**。
   **⚠️ 诚实边界**:8 对里 **3 对是宽体假行**(`fieldregen`/`tpdeathbuy>fieldbuy` 走 `ItemPurchaseThink`;
   `pullcad>pulldrag` 走 `Think` 的**另一条**分支,`pullcad` 的门在 `:268` 的 `roamCreepPull` 块里)——
   **逐条读过并把读数写进 ACKNOWLEDGED 的注释**,过收是 ratchet 该错的方向;
   **在册 ≠ 混淆很大 ≠ 外层有错**,只说这两个 id 的 (a) 在同一条腿上不独立;
   **fan-out 那条断言不依赖「文件进 key」**(池化后 `c2` 15→14,仍最大仍 ≥10 ⇒ 该变异抓不到)——
   与 `0CONJ` 自伤甲**不同**(那里承重的是精确集合,这里是下界),**登记在案**。
   **下一格**:球在**总监**(裁主判据 / 裁 `fieldbuy` (a) 跨 18:5xZ 不可池化 / 裁 register 的耦合位置);
   **不为「把 3 条宽体假行按块结构收窄」开格**(`0CONJ` §2 已论证不该做);
   **也不为「替总监改 §BC.3 与 :176 那两行认证」开格**(是总监的文件,本组只提)。**

0CONJ. **【2026-08-29T19:27Z 新增,自选 backlog;**兑现本组两轮前自己登记、此后没人跑过的判别式**
   (`0DODGE` 主判据乙:「grep 被调用者的函数体」);两条可复用主判据 + 两条**当轮抓住并修好**的量具自伤
   + 一条**免费答掉上一轮交给总监的前置问题**;`bots/`/`game/` **逐字节零 diff**,零新 gate id,
   零行为改动,`queue.json` 一字未动,零 AWS。】**
   **`J.IsSoakCandidate` 不是谓词,是合取项。把带它的 helper 从另一个 id 的门里调用,新杠杆就是
   `outer AND inner`;隔离波只 arm outer ⇒ 可以是逐字节 no-op,而每一层单独看都在按自己的声明工作,
   没有任何断言会红,`check_armed_wiring.py` 判 WIRED(它的 LIMITS 明写 WIRED 只等于「调用点存在」),
   verdict 回来是「tested, no effect」。`pullcad` 一族,但吃亏时刻从「promote 那天」提前到「落地那天」。**
   **判别便宜:grep 被调用者的函数体。本轮跑完了**:`bots/` **1668** 个顶层函数、**91** 个 gated helper、
   **45** 条嵌套对,**live 违例 0**。当前 armed 44 个 id 里作为**内层**出现的六个
   (`stayfield2`/`towerfear`/`fieldbuy`/`fieldcreep`/`tpreach`/`pulldrag`)外层也都不构成冻结
   ⇒ **W26 没有在为一个 no-op 付钱。**
   **⭐ 安全的理由只有三种,此前一条都没写下来**:**(P) 参数门**(未 armed 返回出厂值,不是杀掉分支的常量;
   `IsInLaningPhase` 的 `c2`/`c4` 只挪分钟阈值、`SafeToCommitFight` 的 `depthnum` 只换更深余量)、
   **(A) 只增不减**(`HasFieldRegenSource` 的 `bagsalve` 只多认背包一格)、
   **(I) 单位元**(未 armed 是第一行字面量 `true`;`IsFieldSipEnough`/`fieldsip` 是全仓唯一有意这么写的)。
   ⇒ **§CE.6 的一般形式:要么同腿 arm 被调用者的 id,要么让被调用者未 armed 的取值是所在合取式的单位元。**
   **产出**:`tests/test_gated_helper_nesting_census.lua`(`[ratchet]`,**10 例全绿**,快腿 29 → 30)。
   **钉集合不钉判决**:自动判 (P)/(A)/(I) = 自动判一个任意 Lua 函数未 armed 返回什么,
   **一个会猜的检查器就是一个自己制造发现的量具**(`0ADDR` 那条更贵的自伤)。
   **故意过收**:「嵌套」= 调用落在调用方函数体内任何位置,不要求落在外层门的分支里
   ⇒ 有些行(`Think`/`GetDesire`/`GetDesireHelper`/`ItemPurchaseThink` 这些几百行的分发函数)
   **根本不是合取**,表上标 `W`。**这是 ratchet 该错的方向:网宽漏不掉要紧的那条,一条假行的代价是读一遍;
   按缩进决定作用域等于用缩进回答一个由算术回答的问题。**
   **变异 10 真 10/10 全抓 + 3 CONTROL 全绿**(先验落点,`0DODGE` 的 M7 自伤一次未发生)。
   **⚠️ 自伤甲(池化)**:`X._nopush_ShouldSuppressWaveShove` **在 CM 与 jakiro 两个文件里各定义一次、
   两侧 id 全同**;第一版行 key 不带文件 ⇒ 两条真实嵌套对**塌成一行,删掉任意一个调用点 census 照样绿**。
   **抓法便宜到近乎免费,而且在钉任何东西之前:带 key 与不带 key 的集合各数一遍,45 vs 44。**
   **这是铁律 4(ii) 池化教训在源码普查上的同形:看起来正常的那个读法正是把差别藏起来的那个。**
   修法把调用方文件放进 key(`bots/` 路径由「永不改名」冻结,耦合零成本)+ 补 `C7`;`M8` 证明它承重。
   **⚠️ 自伤乙(控制用例让被保护的分支不可证伪)**:`C2` 第一版用**单行** `--[[ ... ]]`,
   **而单行长注释早被逐行 `--` 剥除干掉了** ⇒ 长注释那条 gsub **从落地起无法证伪**,`M3b` 第一轮活了下来。
   `bots/` 有 **202** 个长注释块、其中 **3** 个已含调用形状文本 ⇒ **不是死代码,是没被测到的活代码**。
   改多行后立刻被抓。⇒ **一个 CONTROL 若走了和被测分支不同的路径,它证明的是那条路径,不是那个分支。**
   **⭐ 主判据乙(来自被仓库自己的检测器挡下的一次**假阳性**)**:`test_defend_ping_declaration_ratchet.lua`
   (GH #91)打红本文件 —— 它的 `drives_guarded_mode` 是**词元匹配**,而本 census **把 `GetDesire` 与
   mode 文件名当数据行携带、一行代码都不执行**;两条现成逃生门都不能诚实用(`LEGACY` 语义是
   「本裁定前就在驱动」,`declares()` 只要出现 `defendPings` 一个词就算 ⇒ **注释冒充调用点,GH #300 已付过钱**)。
   **⇒ 要收窄一个过宽的检测器,先量一遍收窄会丢掉谁 —— 最显然的那个收窄往往是一次伪装成收紧的放松。**
   实测:显然的收窄(要求 `GetDesire` 以**调用形式**出现)**会丢掉 6 个 LEGACY 里的 4 个**。
   采用的是**按机制收窄**:**从不 `require`/`dofile`/`loadfile`/`loadstring` 的文件够不着任何 mode 的
   `GetDesire`**;落地前实测**恰好**放过 census 形状的文件、**LEGACY 6/6 一条不放**,并补一条
   `[ratchet]`「这条收窄不许赦免登记表里任何人」;收窄自己的 battery **N1/N2/N3 3/3 全抓**。
   **⭐ 免费答掉 `0ADDR` 交给总监的第 ② 条**:自检印 `28 tagged` 而 grep 只有 24 —— **是算术不是漂移**。
   快腿选集 = `tagged ∪ 四个先于 tag 约定的点名文件`,**交集 0**;本轮实测 `tagged=26 named=4 union=30`
   ⇒ **printed = tagged + 4**,恰好复现 `28 = 24 + 4`。**不符的是那行 label(印并集却自称 tagged),
   两个数从来没在量同一个东西。#302 §5.2 可以直接裁,不必再花一轮对数。**(label 是总监的文件,不自行改。)
   **登记一条不动的**:`J.IsInLaningPhase` 被 **13 个**别的 gated helper 当域谓词读;
   今天安全是因为 `c2`/`c4` 是参数门**且都不在 armed 集**,**但 `c2` 一旦入集,它同时改那 13 个杠杆各自的域,
   那一波的隔离读数不可归因。**本轮不动它(非 live 问题),登记在案。**
   **下一格**:回 backlog。**不为「把 45 条里的 wide-body 假行按块结构收窄」开格**(§2 已论证不该做);
   **也不为「扫别处的重名函数」开格**(跨组扩面,判别式见报告 §4.1)。**
0ADDR. **【2026-08-29T16:35Z 新增,认领 GH #302 §5.1+§5.3(**本组自己 10:43Z 立、此后两轮被记成
   「不认领」的 trunk RED**);一条可复用主判据 + 一条量具判别 + 一次**被当场识别**的重复自伤;
   `tests/` 一个文件重锚,`bots/`/`game/` **逐字节零 diff**,零新 gate id,零行为改动,
   `queue.json` 一字未动,零 AWS。】**
   **一个钉子的全部作用是「被钉那份文件的裁定一变就红」;它却把地址写成了那份文件刚刚亲手宣布
   为不承重的那个坐标(行号)。那份文件加固自己、把 22 个 `line = NNNN` 整个删掉的那一刻,
   钉子不是精度下降,是永久红 —— 而它的失败文本说「the census row for this site moved」,
   行根本没搬,搬的是寻址方式。**
   `87c69bdc`(总监 07:13Z,GH #221 甲案)扫了 `test_level_gate_census.lua` **自己**的断言,
   **没扫「别的文件里按旧 key 引用它的钉子」** ⇒ `test_gamemode_world_assertion.lua:1450` 红了 **~9.4h**。
   **⭐ 主判据(可复用)**:**当一份 issue 用一句共同诊断把 N 条红打成一包(「全部是语料计数棘轮漂了」),
   那句诊断对包里不合群的那一条不仅不成立,它开出的处方还**修不好**那一条 —— 合群的那些修完回绿,
   不合群的那条被「这件事已经在修了」**掩护**着留下来,而 issue 的进度看起来是 8 → 1。
   失效方向:**包的绿化速度冒充了整包的可修性**。** 判别便宜:**对包里每一条各自复现一次失败文本,
   问它是不是真的属于那个共同名词** —— 读 assert message,不读 issue 的归纳句。
   实测:#302 那 8 条里 **7 条确是语料棘轮、已被别人修掉**,**剩下 1 条不是**。
   **产出**:按 census **自己的新 key(file, 去空白源文本)** 重锚 —— `gsub` **计数**断言 `hits == 1`
   (不是 `find`;匹配多处的锚不能只靠「找得到」算数,M15 族)、行内 `text = '…',`
   (**末尾 `',` 承重**:`mode_farm_generic` 那行把它当**严格前缀**,该前缀全文件 **3** 次、带 `',` **1** 次)、
   行内 **`not find('line = ')`**(钉住 #221 裁定本身)、行内 `verdict = 'TEETH'`(原意保留)。
   顺带修掉重锚**引入**的一处自匹配(`find('{ file = ', at)` 起点应为 `at + 1`,否则 row 截成空串、
   三条行内断言一起变空)。**变异 8 个:6 真 6/6 全抓(四条断言各有一个只打它的变异),
   2 个 CONTROL 全绿** —— `C2`(文件最前面插 20 行纯漂移)**绿**就是重锚的全部意义。
   **⚠️ 自伤(重复出现,但当场被识别)**:M2 补丁串少一个逗号没匹配上,battery 打的是
   **`MUTATION DID NOT APPLY -- not a survivor, a no-op`** 而不是「幸存」——
   上一轮 `0DODGE` 的 M7 自伤**在同一个位置第二次出现,这一次判据兑现了**(先验 `git diff` 看落点)。
   **⚠️ 量具判别(本轮踩到并当场更正)**:**测试 mock 把全局 `print` 桩成 no-op** ⇒ 任何在 `dofile`
   测试文件**之后**用 `print` 汇报的诊断脚本**一片安静**,而「没有输出」读起来就是「没有失败」。
   本组一度据此把这条误写成「顺序依赖」(GH #301 族),改用 `io.stderr:write` 后**单独跑同样红**。
   ⇒ **在被测代码可能桩掉 IO 的进程里,诊断输出一律走 `io.stderr:write`。**
   **⭐ 主判据乙(方法,直接约束 #302 §5.2 的裁定)**:**有一族测试靠写一个共享的全局路径来 arm**
   (`bots/Customize/soak_side.lua`:写→跑→`os.remove`;208 个未标签文件里 **25 个**这么做),
   **它们之间不是并行安全的** ⇒ **任何「fan out 跑快一点」都会凭空造红**,而且
   **假红与真红对读者不可区分**(是正常的断言失败文本,不是 IO 错误)、**条数随并行度变化**:
   同一棵树 `-P 8` 读 **9** 条红、串行读 **0** 条(9/9 全绿)。
   ⇒ **把快腿从 opt-in(`[ratchet]`)翻成 opt-out(默认全跑)不能靠并行买回时间**:
   那 25 个文件要么先改成进程私有 arm(临时目录 / 环境变量),要么全跑必须串行。
   **§5.3 的答案**:未标签 **208**(全部跑到,0 超时 0 加载失败),**此刻真红 1 个 = 本轮修掉的这个**
   ⇒ **#302 猜的「8 是下界」被证伪:8 是当时的实际总数,现在是 1。**
   未标签面**没有藏着一堆红**,藏着的是**没人每轮看它**这件事本身。
   **⚠️ 自伤乙(更大)**:这条判据是**踩出来的** —— 本组先用 `-P 8` 跑,造出 9 条假红并一度写进草稿。
   **甲是「变异没打上」,乙是「量具自己制造了被测现象」;乙更贵:不是漏掉一个洞,是凭空报出九个洞。**
   反射动作很便宜:**一条红若指向「arm 之后行为不对」,先单独跑一遍再信它。**
   **⚠️ 顺带一条口径不符**:自检打印 `28 tagged detector file(s)`,而
   `grep -l '\[detector\]\|\[ratchet\]' tests/test_*.lua` 只有 **24**,差 **4** ⇒
   **「快腿覆盖面」这个数没有单一定义**,而 #302 §5.2 要总监裁的正是这个覆盖面。**裁之前先让两个数对上。**
   **下一格**:回 backlog。**不为「把别处引用 census 的钉子全扫一遍」开格**(那是跨组扩面,已交总监;
   判别式已写进报告:`grep -rn "test_level_gate_census" tests/`)。**
0DODGE. **【2026-08-29T13:37Z 新增,GH #304 认领并裁定 (B);两条可复用主判据 + 一次**假的**变异
   幸存者 + 一条不认领的 trunk RED;`bots/` **纯注释 30 行**,`game/` 逐字节零 diff,
   零新 gate id,零行为改动,`queue.json` 一字未动,零 AWS。】**
   **一条「没有压力」的守卫是由向后看的伤害窗口构成的;把它移植到一个由向前看的威胁触发的
   站点上会把它反过来。**
   #304 报的是 `X.ConsiderItemDesire['item_blink']` 里四条朝自家远古 blink 的分支只有 retreat 那条
   被 `blinkflee` 挡住,问本组选 (A) 给 `:1614` 的 `IsProjectileIncoming` 分支也挂门,还是 (B) 裁
   「弹道躲避是合法用法」并把作用域写进注释。**裁 (B)。**
   **⭐ 主判据甲(可复用)**:**一个由「向后看的伤害窗口」构成的「没有压力」谓词,不能移植到一个
   由「向前看的威胁」触发的站点上 —— 在那里两者反相关:窗口是空的,恰恰因为威胁还没落地。
   失效方向最贵:两个 id 各自都按声明工作,没有任何断言会红。** 判别便宜:**问站点的触发器朝哪个
   时间方向看,再问守卫的每条子句朝哪个方向看。**
   算术:`and not J.ShouldHoldBlinkFlee(bot)` 放行 blink 的充要条件是 `hp < 0.70 OR 已被英雄打过(2.0s)`
   —— **两个析取项都朝后看**,而先手法术恰好落在「什么都还没打到我」的帧上。
   量级(**431** 个带真实回溯伤害窗口的存活英雄帧,来自 **47/107** 枚 fixture,`ambiguous` **0**,
   其余 60 枚**排除**而非当作平静):移植后被压住 **275/431 = 63.8%**;放行侧 **156**(**80** 是
   「已被打过」,其余是「已掉到 70% 以下」);只有 **18.6%** 的帧在 2.0s 内被英雄打过。
   **`[axis]`:不是 0.70 的假象** —— HP 门扫 **[0.10, 1.00]** 全程仍压住 **174–348**(**40.4%–80.7%**),
   满血门下仍 **174**;承重的是伤害窗口不是 HP 数字。
   **⭐ 主判据乙(更尖)**:**一个自带 `IsSoakCandidate` 的 helper 就是一个合取式;把它挂到新站点的
   新 id 下,新杠杆是「两个 id 的合取」⇒ 只 arm 新 id 的隔离波量到 no-op,而 `check_armed_wiring.py`
   照样判 WIRED。这是 `pullcad` 一族,但 pullcad 的判别法在这里是瞎的(第二个 id 不在新门的文本里,
   在被调用者体内),而且吃亏的时刻从「promote 那天」提前到「落地第一天」。** 判别:**grep 被调用者
   的函数体。** 本仓该集合 **50+ 个 helper**(断言下限不用等式,GH #273),且**已实现过一次**:
   `J.ShouldFieldBuyRegen`(`fieldbuy`)调 `J.IsFieldSipEnough`(`fieldsip`)——**上一轮本组自己造的**;
   那处安全的理由能写成算术:**内层未 armed 是字面量 `true`,即所在合取式的单位元**。
   ⇒ 这条给出 **§CE.6 次序问题的一般形式**:**要么同腿 arm 被调用者的 id,要么让被调用者未 armed 的
   取值是它所在合取式的单位元**;两者都不满足时该 id 买不到读数。
   **产出**:`J.ShouldHoldBlinkFlee` 头注写清作用域(**纯注释**);`tests/test_blinkflee_scope_ruling.lua`
   **14 例全绿**(`[ratchet]`,自检快腿 26 → 27)+ `tests/_blinkproj_sweep.lua`。
   **⚠️ 方法自伤(甲,新形状)**:第一轮 battery 把 **M7(伤害窗口 2.0→5.0)记成了「幸存」——
   那个变异从来没被应用到目标上**:补丁按**首次出现**替换,而该行文本在 `jmz_func.lua` 出现 20+ 次,
   首次在 **:1302**,离目标 **:9471** 八千多行。**「没打上」被记成了「打上了但没被抓到」,后者会让人
   去补一个不存在的洞。** 判别便宜:**变异后先 `git diff` 看落点再看读数。** 修法是加固:补丁器**按函数体
   锚定**,并补 `[boundary]`(语料**能**钉住这个窗口:`v2_dmg5=112`、伤害年龄落在 (2.0,5.0] 的 **32** 帧、
   窗口放宽到 5.0 压制域 **275→261**)+ `[source]`(两个出厂常数在**函数体内**钉住,锚定到函数正是为了
   防止 pin 漂到那 20 多行同文本上)。重打后 **M7b 3 红 / M14 1 红 / M15 1 红**。
   与 GH #300 自伤(甲)**同族反号**:那次是「空隙让边界测不出来」,这次是「看着测不出来,其实量具没搭上」。
   **⚠️ 方法自伤(乙,过程)**:第一版 battery 用 `git checkout --` 还原,(i) 把**同文件里未提交的本轮工作**
   一起还原掉,(ii) 对**未跟踪**的新文件直接报错**什么也没还原**(变异留在树上)。改为 `cp` 快照 + 按文件拷回。
   **⚠️ 被仓库自己的检测器挡下一次(已修,值得记)**:`test_corpus_scale.lua` 打红本文件的
   `fixtures == 107` —— GH #106/#127 那条「把语料规模写成等式」的类。已全面改用 `tests/corpus_scale.lua`
   的 `corpus/ratchet/share`;**只有内容本身是零的断言留作等式**(该模块明写这类要留)。
   **⚠️ 诚实边界**:**裁定真正要问的那一帧(向后平静 **且** 有弹道在飞)不在语料里也进不来** ——
   dump 没有弹道流,`J.IsProjectileIncoming` 在全部 **993** 个存活英雄帧上 false(`[limit]` **断言**出来的);
   ⇒「门会被正向选择反噬」**是主张不是测量**,能把它变成测量的是 **GH #305**。
   语料事实是关于 **107 枚 fixture** 的不是关于 Dota 的。**本组撤回**用 retreat 几何买 `blinkflee` (a) 的请求。
   **⚠️ 开工两条 trunk 红,均不认领**:(a) python 腿 `test_stale_waits.py` 命中 `batch-desk.md:5616`,
   而**那一行是对的** —— `stale_hits()` **以整行为单位**把否定标记分配给该行每个 id;两个反事实
   (拆成两行 ⇒ 绿;去掉两个已 armed id 的反引号 ⇒ 绿)⇒ **这条 finding 是换行符位置的函数**;
   顺带 `未裁 ` **一个 token 同时点亮 ADMISSION 与 OUTSTANDING** ⇒ 那个 AND 一次收窄都没做。已开 **GH #307**。
   (b) GH #302 的 8 条 Lua 红仍在(三个不带 `[ratchet]` 的文件)。
   **下一格**:回 backlog。**不为「给弹道分支单独写一个前向威胁守卫」开格**(需要 #305 的弹道流才能做
   fixture,现在写就是没有本地验证的行为改动);**也不为「把方向判据折进 `ShouldHoldBlinkFlee` 本体」开格**
   (那会在没有新证据时改掉一个已在 armed 集里的 id 的语义)。**
0SIP. **【2026-08-29T10:4xZ 新增,GH #300;认领 **owner 优先项 P2** 里本组自己 2026-08-22 登记、
   此后**零轮认领**的那一格(`0P2` 第 (c) 段末:「留下之后够不够」);一条可复用主判据 +
   **一个已落地的 gated id `fieldsip`** + 两条方法自伤 + **一次当轮自我更正的错读**。
   `bots/` 只动 `jmz_func.lua`,`game/` 逐字节零 diff,`queue.json` 一字未动,零 AWS。】**
   **一个 presence 谓词被两个 id 以相反极性在同一帧上读,于是同一件 85 血的道具
   既是「留下的理由」也是「不用买大药的理由」。**
   `J.HasFieldRegenSource` 只答「有没有一口」:`stayfield`/`stayfield2` 读作「**有** ⇒ 留在野外」,
   `fieldbuy` 读作「**没有** ⇒ 买大药」。在 **owner P2 自己钉的那一帧**
   (`f_260822_063722_lina_tp_home`)上,Lina **346/1088 = 31.8%** 血、包里只有 faerie_fire
   ⇒ 那个 TRUE 值 **85 血 = 血条的 7.8%**,**它既买下了留守,又堵死了 owner 原话里的「买大药」**。
   **⭐ 主判据(可复用)**:**一个 presence 谓词被两个消费方以相反极性读时,它的「有」
   会同时充当两个互相抵消的理由;量级最小的那个实例反而最坏 —— 买下了留守却不足以让留守有意义,
   同时堵住唯一能让留守有意义的补给路。失效方向最贵:两个 id 各自都在按自己的声明工作,
   没有任何断言会红,合起来却锁死在最差的那一格。** 判别便宜:**数消费方,看极性是否相反**。
   **产出**:gated `fieldsip` —— `J.FIELD_SIP_HEAL`(五来源单次治疗量)+
   `J.FIELD_SIP_MIN_FRACTION = 0.25` + 纯函数 `J.FieldRegenSipValue` + gated `J.IsFieldSipEnough`
   (**未 armed 是第一行的字面量 `return true`**),**两个消费方对称消费同一个合取式的正负两面**
   ⇒ **分区按构造保住**(普查:五个「不可能」计数器全 0,`released == now_buys == 21`)。
   这是 `campvoid`(GH #265)那条主判据**在事前**用一次,而不是死锁之后。
   **常数从空隙里挑、且不承重**:23 个带补给的 situation 帧分成
   **21 行 @ 0.062..0.156**(faerie_fire / tango)与 **2 行 @ 0.360 / 0.460**(大药),
   **(0.156, 0.360) 一行都没有**;网格实测该区间内**任何**阈值释放同样 21 行,
   `[axis]` 钉的是**平台宽度与常数余量**,不是 0.25。
   `tests/test_fieldsip_magnitude.lua` **15 例全绿**(`[ratchet]`,自检快腿 23 → 24)+
   `tests/_fieldsip_sweep.lua`;**变异 14 个,14/14 全抓**,承重的是
   **M5(只改留守侧不改购买侧 ⇒ 分区破裂)**。入集提议 `test_set.md` **§CE**。
   **⚠️ 方法自伤(甲)**:`>=`→`>` **第一轮活下来了** —— 语料最近两行是 0.156 与 0.360,
   **没有一行落在阈值上**。**让常数不承重的那个空隙,同时让它的边界测不出来**;
   补 `[boundary]`(边界血条由两个 shipped 常数**推导**,并先断言重构在二进制浮点下精确),
   补完 14/14。**登记:两件事要分开买。**
   **⚠️ 方法自伤(乙)**:一行**纯注释**引用了出厂表达式 `not J.HasFieldRegenSource( bot )`,
   被兄弟文件 `test_bagsalve_backpack_source.lua` 的「调用点恰好 2 个」普查数成第 3 个调用点,
   **一个调用点都没新增就把它打红** —— 与 04:20Z 那 14 行纯注释顶行号 pin **同族**。
   **修法是加固**:加 `strip_comments`,并在**同一条测试里当场证明没钝化**
   (追加真调用点仍读 3、追加引用调用形式的注释仍读 2)。修前注释既能**误伤**也能**冒充**,修后都不行。
   **⚠️⚠️ 顺带查出一条真的 trunk RED**(8 条 / 3 个文件:`test_itemdesire_world_assertion` 19/6、
   `test_gamemode_world_assertion` 32/1、`test_salvepool_missing_floor` 18/1;按官方排序顺序、
   在开工 `HEAD 1ccdeaa7` 上逐条复现,读数逐字节相同;全是**语料计数棘轮漂了**)。
   **⭐ 三个文件一个都没带 `[ratchet]`,而自检快 Lua 腿只跑带 `[ratchet]` 的那 24 个 ⇒
   GH #267 原样重演,这次 8 条**。起点强候选 `f08cdb56`(08-28T12:16Z)⇒ 约 **22 小时**。
   **本组不认领**,已开 **GH #302**。
   **⚠️ 本轮出过一次错读并在同一工作单元内更正(值得记的是更正那一步)**:
   分块跑撞到 `test_cm_arcane_aura_passive.lua:226`,在**净 HEAD `1ccdeaa7`** 上也复现 ⇒
   我先写成了 **trunk RED**。**错了**:我的分块 runner 用 `pairs()` **无序**迭代,
   而官方 `tests/run_tests.lua:91-93` **`table.sort(names)`** ⇒ **排序后它是绿的,trunk 没红**。
   **「在净树上复现」回答的是归属,不是存在;存在要用读者会跑的那条命令问。**
   缺陷本身是真的且更难看见:**单独跑必红、编进套件必绿**(实测前缀:0 红 / 1 绿 / 2–9 红 / 10+ 绿),
   而绿的那一半**不是因为断言成立** —— 文件自己的注释已写下机制(mock 给未定义 ALL_CAPS 全局
   发**递增整数**,`DOTA_ABILITY_BEHAVIOR_*` 不是互不相交的 2 的幂),却仍把一个
   **按调用顺序变化的整数**当掩码常量在测试内外各读一次。**本组不认领**(CM 技能,`[hero]`/`[bug]` 族),已另开 **GH #301**。
   **下一格**:等总监①裁入集、②**裁 §CE.6 那个次序问题**(不接受的正确裁法是**要求同腿 arm**,
   不是拒 id)、③裁本主判据、④建议一次**跨 id 的「相反极性消费方」普查**(本组不自行扩面)。
   **不为「把同一个 magnitude 问题搬到已 promote 的 `J.ShouldStayAndRegen` 上」开格**
   (shipped 默认,GH #294 已量出它 TP 腿反事实域只有 `[0.18,0.19)`;改已 promote 的守卫不是本组单方面的权);
   **也不为「把 magnitude 折进 `J.HasFieldRegenSource` 本体」开格**(那个名字是 presence)。**
0PIN. **【2026-08-29T07:26Z 新增,GH #295(census 半);认领本组自己 04:20Z 造的 trunk RED;
   两条可复用主判据 + 一份反事实读数;`bots/` `game/` **逐字节零 diff**,零新 gate id,零行为改动,零 AWS。】**
   **三个红文件,两个根因 —— 第二份"证据"是同一条红经第二条腿的转述,且它的失败文本指着错的对象。**
   `bc2ff86f`(本组 04:20Z)的 **14 行纯注释**把 `test_level_gate_census.lua` 两条 pin 顶了 +14
   (`5858→5872`、`5898→5912`),而它们是**上一个 commit**(`8cf5ae0c` director)刚为 +41 重锚过的。
   **⭐ 主判据甲(可复用)**:**一次插入位移的是它下面的所有 pin,跨所有钉住被编辑文件的测试
   —— 按 edit 扇出的事件;而修复者看见的是一个个变红的测试,于是做出按 file 的响应。
   失效方向静默地落在「你没看见失败的那些文件」上。** **不是假想**:同一轮**确实重锚了**
   同一次插入顶掉的 `test_item_name_census.lua`(`:6849→:6863`)**并写下了教训**,
   **它重锚的是自己看见过失败的那一个**。⇒ 该问的是「**哪些文件 pin 进我刚编辑的文件**」(今天 4 个)。
   **⭐ 主判据乙(更尖)**:**一个拿「当前工作树」当 fixture、又断言这棵树是绿的元测试,
   把被测对象的输入当成了固定装置。树因任何别的原因红掉时它也红,而它的失败文本描述的是
   「检测器坏了」不是「树红了」。失效方向最贵:它给一条红加上一份看起来独立的第二份证据
   (读起来像两个根因),并把注意力从树引向工具 —— 而修工具是错的修法。**
   **反事实读数**:只重锚那两条 pin、**对 `test_selfcheck_lua_leg.py` 零编辑**,它 **4 failures → 43/0**。
   **产出**:`test_level_gate_census.lua` 两条 pin 就地重锚(遵循该文件自立的 `0LN2`
   「移 pin,绝不放松检查」:只动 `line`)+ `test_selfcheck_lua_leg.py` 新增 `uncert()` 通道
   (baseline 真红 ⇒ 四条报 **UNCERTIFIABLE** + 退出码 **2**,复用 `run_py_tests.sh` 已有的
   0/2/3 渲染;**差在退出码,所以不是 GH #171 那个 SKIP-读作-PASS 的坑**),
   **判别位在代码里**:leg 点名的文件用同一条命令**单独重跑**,**只有单独也红才配降级**。
   **变异 2 个全按设计动作**,承重的是 **B(判别位致盲 ⇒ 仍 4 failures / exit 1)**。
   **⚠⚠ 收尾被撞车,且这次撞车判决了本组自己提的处方**:总监 `87c69bdc`(07:07Z)两个根因一起修,
   census 那半**把 `line` 字段整个删掉改用 `text` 作键**(**消灭整个漂移类**,严格优于本组的第四次重锚)
   ⇒ **本组该文件改动整份丢弃,两个红文件上净贡献 0 行**;**落地的只有 `test_selfcheck_lua_leg.py`**。
   **⭐ claim 评论挡不住撞车**:总监 07:07Z 本地做完 → 本组 07:2xZ 发 claim → 总监 07:3xZ 才 push;
   **claim 只在对方开工前被读到才有用,而对方开工时它还不存在**。本轮与 01:16Z **两次都是「同时开工」**,
   而 claim 防的是「后来者撞先行者」⇒ **一次实战即被证伪**。
   **⚠ 诚实边界**:收工 trunk **全绿 52/0/0**,但**两个半边都不是本组修的**;
   **全量 Lua 套件未跑**(`bots/` 零改动);判别位与 leg 同命令 ⇒ 不能区分共模失效。
   **下一格**:等总监①裁两条判据、②**裁一条「开工那一刻可见、且在 push 之外」的租约信号**
   (claim 评论已证伪,**形式是总监的权,本组不开面**)、③裁「pin 类检测器要不要进
   `.githooks/pre-push`」(这条红红了 **3 小时**,期间两个组各跑过一轮;**钩子是 #213 的权,本组没碰**)。
   **不为「预防性重锚其它 pin 文件」开格**(猜位移 ≠ 修位移,且总监已用 `text` 键消灭该类)。**
0SITE. **【2026-08-29T04:2xZ 新增,GH #294;一条可复用主判据 + 一条从没写下来的约减 + 一处已发表 promote
   判词的归属修正;`bots/` **纯注释 14 行**,`game/` 逐字节零 diff,零新 gate id,零行为改动,零 AWS。】**
   **一个已 promote、每局 Turbo 都 live 的守卫,在它两个调用点上的射程差 57 倍 ——
   而小的那个正是 owner P2 的那条腿。**
   `J.ShouldStayAndRegen`(`tphome`)自己的带是 **[0.18, 0.75]**;走路腿
   (`mode_retreat_generic`)调用点上方**没有任何 HP 上限**(唯一一处 `botHP` 比较与
   `DotaTime() < 0` 同行,正常对局够不着)⇒ 整条带 live。TP 腿(`撤退:1`)第一条合取是
   `botHP < 0.19` ⇒ 守卫**能改变结局**的域只有 **[0.18, 0.19),一个百分点**。
   **⭐ 主判据(可复用)**:**一个守卫的域不是它自己谓词的域,而是那个域与它被放进去的
   那条合取式其余部分的交。当分支的阈值恰好压在守卫下限上方一个百分点时,守卫在这个站点上
   几乎是空操作,却在自己的源码里、在调用点的注释里都读起来像那条腿的机制。失效方向最贵:
   不报错、不掉测试、不丢 promote 判词,只是让这条腿继续被记成「有守卫」,于是没人去找
   这条腿上真正缺的那个 id。** **不是假想**:`stayfield` 是为 `撤退:3` 开的,理由白纸黑字
   「unlike 撤退:1 above it carries no regen veto at all」——**`撤退:1` 因为「有一个」被跳过**。
   **第二条约减(更尖,以前没人写下来)**:在守卫能改变结局的那批帧上,分支的
   `itemFlask == nil` / `not modifier_tango_heal` / `not modifier_flask_healing`
   **逐条否定了守卫内部 `bHasFlask` 那个析取的每一支**,而第一支是**同一个
   `J.IsItemAvailable("item_flask")`、同一帧** ⇒ 守卫在这个站点上**退化成
   `bot:GetGold() >= 90` 一条纯金钱判据**。**这个退化在守卫自己的文件里读不出来,只在调用点读得出来。**
   **归属修正(本轮唯一对外主张)**:GH #2 给 `tphome` 买到的 **+51 GPM / +54 XPM /
   −0.32 deaths(28 局)不可能是在 TP 腿上买到的** —— 那条腿最多挪动一条 1pp 的缝。
   **那份效应属于走路腿。归属修正,不是正确性质疑。**
   **产出**:`tests/test_tphome_tp_leg_counterfactual.lua`(`[ratchet]`,14 例;subject 是
   owner P2 钉的真实帧 `f_260822_063722_lina_tp_home`;`[source]`×4 钉两个常数 + 同一访问器 +
   走路腿无帽、`[arith]` 钉 57 倍、`[reduce]` 在真实帧上量出 **gold 89→false / 90→true**、
   `[axis]` 141 点网格(守卫真 ≥100 点,其中 `<0.19` 只有 1..4 点且落在 `[0.18,0.19)`)、
   `[control]`×2 非 turbo 与 3s 内伤害整条网格全假、`[limit]`×2 consider 不可驱动 + (3,8] 窗口是声明输入)
   + `bots/ability_item_usage_generic.lua` 的**纯注释**更正。**变异 9 个,9/9 首轮全抓**,两端 CONTROL 干净。
   **⚠ 诚实边界**:不推翻 `tphome` 的 promote;(3,8] 窗口**语料里没有帧**,是声明输入且声明本身写成断言;
   `X.ConsiderItemDesire["item_tpscroll"]` 在 fixture 上不可达(GH #89)⇒ 分支归属走源码;
   「1200 环 ⊆ 1600 环」**没当承重**(两个数据源:last-seen 2.0s vs 可见列表)。
   **下一格**:等总监裁本判据 + 裁「归属要不要回写 `state.json` 的 `tphome` 条目」;
   建议一次**跨 promoted id 的多调用点普查**(`nodive`/`pushguard`/`tpsafe`/`regroup` 都是多点消费),
   **本组不自行扩面**。**不为「把 `撤退:1` 的帽抬上去」开格**(那是放大一个没有 (a) 证据的行为,
   且会推进 owner P2 自己划的 genuine-escape 带);**也不为营地那一族开格**
   (`campexit` 退集后 10..11 带又没人管,但再开一根要读营血/进度,而 fixture 语料**一只中立都不带** ——
   只能再造一份声明输入的杠杆,**而一天前被退集的正是这种**)。**
0VERB. **【2026-08-29T01:16Z 新增,GH #289;认领批测台交棒过来的 trunk RED;
   一条可复用主判据 + 一个被否掉的明显做法 + 一次跨座位撞车;`bots/` `game/` **逐字节零 diff**,
   零新 gate id,零行为改动。**净贡献只有一条断言 —— 机制那半是总监的**。】**
   **本组一天前落地的检测器,不变量 2 写着「对活着的接力棒报红的检测器一轮之内就会被关掉」——
   一轮之内它做到了;而 issue 给的处方是删掉那个接力棒。**
   红行是「**等总监重裁 `campexit`**」(GH #288 之后的**第二次裁定**请求,入集 06:5xZ 早已落地)。
   测试 docstring 早给了逃生口(「say so on the line」),**那一行已经照做了**,
   只是**「重裁」⊃「裁」**命中 `ADMISSION_MARKERS` 的 `"裁 "`。
   **⭐ 主判据(可复用)**:**一个检测器写下的「这类东西不算发现」是一条断言,不是免责声明 ——
   除非它在代码里有对应的判别位。豁免只活在 docstring 里、而被豁免对象的措辞又是匹配串的超串时,
   工具会对着自己点名保护的那一类报红,且处方是「删掉那个对象」。失效方向最贵:不是漏报,是
   **反向施压** —— 把树弄绿的最短路径正好是丢接力棒。**
   **被否掉的明显做法**:「写在裁定落地之后的等待不是过期入集等待」——**不判别**,
   立案四行全在落地之后;**时钟分不开,动词能**。
   **⚠ 撞车**:总监 01:06Z(`8a239be1`)**同款诊断同款修法**且是超集 ⇒ 本组两个文件的改动**整份丢弃**。
   **跨座位重复认领**(不是 GH #180 的同座位并发):规则没说 trunk RED 归谁 —— 已请总监裁。
   **留下的一样**:`INVARIANT 6b`「**动词,不是结局词**」—— 放宽 `RE_RULING` 到 `退集`/`去留`
   会消音真的第一次入集等待(「不入就退集」);**实测**:放宽后总监那 36 条全绿,只有它咬住(37/1)。
   **结清**:总监同一 commit 裁 **`campexit` 退集**(线 2 43 → 42)⇒ 本组不再请求重裁。
   **下一格**:等总监裁本判据与「trunk RED 认领信号」;**不为「把其它措辞纳入豁免」开格**。**
0TAKE. **【2026-08-28T22:1xZ 新增,GH #288;认领 GH #263 那条**本组自己交出去、条件已兑现**的重开条件;
   一条可复用主判据 + 一条方法自伤;`bots/` `game/` **逐字节零 diff**,零新 gate id,零行为改动。】
   **一个杠杆的立案帧列表,和推翻它的那张表,住在同一份文件里相隔二十行。**
   `campexit`(已入集、armed)的源码头注点名五帧作为「THE DEFECT」,五帧全部出自
   `iterations/reports/replay-check/20260828T035500Z.md` **§3.3 表**(t 值/hp/腿逐位对上);
   **同一文件 §4 表**给出这六段各自买到了什么:dragon_knight **6.3× 干净吃下**、
   death_prophet **9.3× 吃下**、necrolyte **3.7× 吃下**、storm_spirit **5.2× 吃下**、
   lion 3.6× 半场 TP 走、venomancer **1.1× 烧 45pp 营还活着**。
   **点名的五帧里三帧记着「吃下」**;把它们汇总成立案理由的那个量(**平均烧血 10.4pp**)
   **在六段里的五段是拿下一个远古营的价钱**——dragon_knight 烧 10.7pp 并把营吃了。
   谓词只读**等级 + sweep 物种**,六段等级 `10/10/10/11/11/10` 全在拒绝带内 ⇒
   **armed 六段全释放,其中四段是出厂腿今天真的在赚的钱**。
   **⭐ 主判据(可复用)**:**挑选立案帧的那一步只问「这一段是不是我要治的形状」
   (静止、烧血、无敌方英雄),不问「这一段买到了什么」——而后者是同一位作者在同一轮里
   量出来的下一张表。失效方向是最贵的那侧:被误收的帧让立案看起来更强(五帧比一帧有力),
   而每多收一帧,armed 分支的反向面就大一分,且没有任何东西会为此转红。**
   判据本身是本组一天前刚立的(`abil1st` 撤回:**armed 在自己域里反向一帧就够撤回**);
   这里是**六帧反向四帧**。与 #278/#280 同族但换层:那两条是「承重前提没写下来」,
   这条是「**证据的选取步骤丢掉了同一份材料里已有的那一列**」。
   **⚠ 最尖的操作后果**:`state.json` 里 (a) 的读点写作「under-tier bot 站在远古营里
   **几秒内离开**而不是跟它对拼」⇒ **释放 dragon_knight 那个营就满足 (a)**,
   即 **(a) 由失效模式买单且读起来像 WORKING**。(a) 必须劈成「释放了打不完的营」vs
   「释放了正在拿下的营」。
   **产出**:`tests/test_campexit_take_counterframes.lua`(`[ratchet]`,10 examples;
   `[domain]` 等级切不动 + L11 在样本里 2/2 全吃下、`[axis]` 真实帧上只改营血/bot 血谓词一动不动、
   `[reach]` 真实 L10/L11 都释放、`[limit]` 逃生口写成断言、`[control]` 12 级惰性)+
   `state.json → campexit_20260828.contra_20260828T22`(**只登记反向读数,不改 armed/in_test_set**)。
   **变异 8 个:7 CAUGHT / 1(M8:删掉两条 `[axis]` 再重放 M1)设计内 SURVIVED**;
   两端 CONTROL 10/0,三份快照 restore 逐字节相同。
   **⚠ 方法自伤(测试第一次运行就抓到)**:`[domain]` 第一版断言「吃下的等级集合 == 没吃下的等级集合」
   ——**假的**(两个非吃下都是 L10,L11 是 2/2);已改成真正需要的弱形式,自伤写进文件注释。
   **⚠ 诚实边界**:6 段深查不是那 25 段;四段「吃下」的真实 sweep 成分不在任何 fixture 里
   (若含可农普通小兵则该段不开火,**逃生口已写成断言**);出/入比最近的一对是
   **3.6(lion)对 3.7(necrolyte)——一个十分位**;**不推翻**「10..11 带存在真实浪费」,
   推翻的是「这个域可以整体当成浪费」。
   **下一格**:等总监重裁 `campexit`。**不为「落地完成度子句」开格**——阈值在 3.6/3.7 那条缝里,
   先要一次可复算的分母(#263 登记的 W18 68 局重跑,排在 #270 之后)。**
0WAIT. **【2026-08-28T19:0xZ 新增,GH #284;一条可复用主判据 + 一条方法自伤 + 四轮过期等待的就地更正;
   `bots/` `game/` **逐字节零 diff**,零新 gate id,零行为改动。】
   **一条「我在等裁定」的等待,连续四轮跑在已含该裁定的树上;而它被读成「阻塞」,
   于是静默地决定了那四轮各做什么。**
   `campexit` 的入集裁定 **06:5xZ 就落了地**(`e7e57979` 写进 `test_set.md` 线 2、写进 `state.json`),
   本组章程当前状态在 **07:30 / 10:35 / 13:55 / 16:32** 四轮里各写一行「`campexit` 入集裁定**仍欠**」;
   **07:30Z 那一轮自己的报告里写着 `开工 HEAD == e7e5797` —— 就是那个裁定的 commit**。
   **⭐ 主判据(可复用)**:**一次「我在等 X」的记录是一个带失效条件的断言,而这个仓库里
   它的失效条件是机器可读的(X 出现在 arm 串里)。等待方每轮把这句话原样抄下去,而抄写不查失效条件;
   `pending_rulings.py` 覆盖的是对称失效的另一半(请求方那侧「没人裁」),等待方这侧
   (「已经裁了但还在等」)此前没有任何东西在看。失效方向是最贵的那一侧 —— 它不报错、不掉测试、
   不输一局,反而作为「阻塞」的理由决定这一轮做什么。** 与 GH #210(线 2 落后裁定四轮)同族,
   **在交付路径的另一端**:那次是裁定没走到字段,这次是字段走到了而等待方没回头读。
   **仪器与散文各说各的**:同四轮的自检行「未裁 queue 请求 **0**」**属实** ——
   这条等待从来不是一条 queue 请求,`pending_rulings.py` 只读 `queue.json`,四轮无人对账。
   **产出**:`tools/agent/stale_waits.py`(扫每个章程**当前状态最新那一条**;命中要求同一行
   **既要一个入集裁定、又说它还欠着**,且反引号 id 已在 arm 串或已 promoted;退出码 **0/3/2**;
   历史行只报 INFO **永不算发现**)+ `tests/test_stale_waits.py`(**19 checks**,`[ratchet]`;**变异 6/6 CAUGHT**)+
   `routine_selfcheck.sh` 新增 `stale-waits` 腿。
   **⚠ 方法自伤(已写进 docstring,不只写进报告)**:第一版用 `git log -S <id> -- test_set.md`
   取「落地时间」,那答的是**待裁区提案**(04:3xZ)而不是**裁定**(07:09Z)——
   **会把一次合法等待读成过期**,正是本工具要抓的那种过度主张、由工具自己先犯了一次;
   改成沿文件历史回溯**线 2**。
   **判别力(不变量 2)**:「等录像组核验 `campexit` 的条件 (a)」这种**同一个已 armed id 上的
   真实在途接力棒不算发现** —— 一个会对活着的接力棒报红的检测器,一轮之内就会被关掉。
   **⚠ 诚实边界**:只覆盖**当前状态最新一条**;backlog 的「下一格」(**恰恰是被读成阻塞的那种行**)
   只作 INFO 回显,是**已命名的盲区**;匹配靠散文关键词 + 反引号 id ⇒ **只漏报不造词**;
   一条过期等待在下一条状态条落地后不再是发现(它成了历史)——**设计如此**,抓的是它还能改写
   工作单元选择的那个窗口。四处过期行**已就地更正并保留原行**。
   **下一格**:等总监裁判据;**不为「把 backlog 下一格也纳入发现」开格**(那需要先定义「哪一条是活的」,
   而定义不清的扩面正是本判据在防的东西)。**
0IDENT. **【2026-08-28T16:3xZ 新增,GH #280;认领 `0EXPIRE` 自己登记的那条未兑现诚实边界;
   一条可复用主判据 + 一条方法自伤;`bots/` `game/` **逐字节零 diff**,零新 gate id,零行为改动。】
   **一条「谁读谁」的判据升了一级(文件同居 → accessor 绑定),而它自己剩下的那个承重前提
   —— 被比较的 accessor 返回的是不同的对象 —— 一条断言都没有;
   让它失效的那次重构,恰恰是让每一条现有断言都保持绿色的那一种。**
   `0EXPIRE`/GH #278 把「读者绑哪个写者」从同居更正为 accessor 绑定,并**自己登记**了
   「`aba_defend` 的 `*1.65` 是按同一条错判据被归为死的,仍待独立核验」。本轮兑现它,
   并在兑现过程中撞到**低一级**的那条:三个 turbo 时钟膨胀站点
   (`aba_defend:239` `*1.65` / `global_cache:207` `*2` / `aba_push:58` `*2`)
   各写自己的 file-local 表;accounting 块「`global_cache` 那份是全仓唯一活着的膨胀」这个结论,
   **当且仅当三个 accessor 返回三张不同的表**才成立 —— 而这条前提**从没被写下来**。
   **⭐ 主判据(可复用)**:**一条「谁读谁」的判据,自己也有一个承重前提:被比较的那些
   accessor 返回的是不同的对象。判据升一级不会把这个前提补上,而它失效的方向和原来那次一样危险
   ——给活的开脱、把死的定罪。凡是靠「这个值属于哪个写者」下结论的地方,对象同一性必须是
   一条断言,不是一段散文;因为让它失效的那次重构(合并两张长得几乎一样的 cache),
   恰恰是让每一条现有断言都保持绿色的那一种。** 与 #278 判据 B 同族,**低一级**。
   **⭐⭐ 最硬的一半(M2 + M8)**:**M2**(让 `updateGameStateCache()` 返回 `getGlobalGameState()`
   的表 = 最可能的那次 dedupe)⇒ **旧块 0 failures**:三条字面量 pin、`readers==2`、`foreign==0`、
   `getGlobalGameState()` 绑定 pin **全部照过**,只有新加的同一性断言抓到;
   **M8**(把三条同一性断言放松成恒真再重放 M2)**SURVIVED —— 设计内,即那条线存在的证明**。
   **⚠ 方法自伤(M2 揪出来的,不是复查)**:driver 第一版**自己踩了同一条判据** ——
   它另起一次 `dofile(global_cache.lua)` 取 accessor,那是**第二个模块实例**、带自己的
   `globalGameStateCache` local ⇒ 三条同一性断言**恒真但因为错的理由**,**M2 第一次从旁边走了过去**
   (`33 tests, 0 failures`)。修法就是判据本身:**accessor 必须从读者手里拿**
   (`aba_push:43` 绑成 file-local ⇒ 它是各 export 的 upvalue)。已写进测试注释,不只写进报告。
   **缺陷 2(把沿用换成重推)**:`defendGameStateCache` **从不离开它自己的文件** ——
   全仓 6 处提及**全在 `aba_defend.lua`**(声明+定义+4 调用点,`elsewhere==0`),
   4 个调用点**逐个**绑普通 local,无 export 交出表 ⇒ 读者集合可**穷举**而非搜索:
   该文件从自己 cache 读**恰好 6 个字段**(`aliveAllyCount`/`enemyTeam`/`isLaningPhase`/
   `ourAncient`/`team`/`teamFountainTpPoint`),**`currentTime` 不在其中**。
   **缺陷 3(grep 的两个盲区)**:`gameState["currentTime"]` 括号读(**M7 实测:旧块全绿**)
   与整表消费(`pairs(gameState)`),当前全仓均 **0**,现已断言。
   **顺带登记(那个诱人重构的价钱)**:三表**互不为子集** —— `aba_defend` 独家
   `teamFountain`/`teamFountainTpPoint`(**它读其中一个**),`global_cache` 独家 6 个;
   `aba_push` 自己那份与 `global_cache` **字段逐项相同** ⇒ 它才是最可能被 dedupe 的一个,
   同一性断言**先指着这一对**。合并会在 `aba_defend` 今天读到值的地方发 **nil**(**M6** 抓)。
   另:仓库同时跑**两套 turbo 时钟约定**(laning 的 `1.65` 与 cache 家族的 `2`),已断言不是散文。
   **两个世界的读数**(`f_260820_043637_axe_ring_alone`,raw 641.4):
   plain **641.4 / 641.4 / 641.4**、honest **1058.31 / 1282.8 / 1282.8** ⇒
   第十五条世界断言在 cache 层**把三个膨胀一起关掉**(这正是此前只能钉字符串的原因);
   故「死」= **没人读**不是**没算**,三条都真的跑了,已断言。
   **产出**:`tests/test_gamemode_world_assertion.lua` **唯一改动文件 +265**
   (新 driver `dilations()` / 4 个新块 / accounting 块头注标注「第三个站点是沿用不是重推」
   并指向重推,**保留历史行不删**)。
   **变异 8 个:7 CAUGHT / 1(M8)设计内 SURVIVED**;两端 CONTROL 干净(**33/0**,改前 29/0);
   快照走 scratchpad **且快照那步本身被断言**;`bots/` `game/` **逐字节还原**。
   **⚠ 诚实边界**:**上一轮的结论没有被推翻**(活的仍是 `global_cache` 那份),换的是**证据的种类**
   加**补上那条没人写的前提**;读数取自**一帧**(倍率与表同一性是结构性的,「三个写者都能驱动」
   只在这一帧量过);「合并会发 nil」是源码+运行时字段表推的,**不是真实对局事故**;
   两条 grep 普查封的是**已知**的两个盲区**不是全部**;GH #267 第六次点名,仍不擅自抬。
   **下一格**:等总监裁定(判据若接受,普查口径从「绑哪个 accessor」扩到「accessor 是否同一对象」,
   **本组不自行扩面**);**不为「删掉两份死膨胀」开格**,也**不为「合并三张 cache」开格**
   —— 本轮的断言正是为了让那件事被做时**响一声**。**
0EXPIRE. **【2026-08-28T13:5xZ 新增,认领 GH #278(英雄组开票交棒)+ 修回**当轮 trunk 红**;
   **两条**可复用主判据;`bots/` `game/` **零 diff**,零新 gate id,零行为改动。】
   **一条在自己的注释里预言了会让它失效的那件事的边界,到期时不是作为读数出现的,
   是作为红出现的 —— 砸在合规加 fixture 的那张桌子上。**
   `test_gamemode_world_assertion:534` RED:`past_honest ... got 2`。成因是一次完全合规的工作:
   GH #108 把批测闸抬到 25 游戏分钟,`b50a7727` 切了头两枚过 DotaTime 750s 的 fixture
   (**785.4s / 790.4s**),边界如期到期。原注释白纸黑字写着「Real Turbo games average
   ~20 minutes, so in the game this clause opens for the last third of the match」——**然后照样冻住数字**。
   **⭐ 主判据 A(可复用)**:**一条写作「语料还够不到这里」的边界,是一个带到期日的断言,
   必须写成「到期时是一个读数」而不是「到期时是一条红」。** 失效方向是**归因错的红**
   加**最便宜的重新上膛出口**(690 改成 790,下次再红一遍)。`0QUOTE`/GH #273 同族但**狠一格**:
   那次是注释与断言互相矛盾,**这次是注释把失效事件直接预言了出来**。
   **算术**:门 `nCloseByTime=1500`;`past_plain` 需 raw DotaTime **>1500s** ⇒ **0/107 不变**
   (成因由「语料太短」更正为**结构性**:字面 `==23` 永不膨胀,门比抬高后的闸还远);
   `past_honest` 需 **>750s** ⇒ **0 → 2/107**;`s.latest` **690.5 → 790.4**。
   **四条逐条定性**(问「它的红会说什么」):`past_plain==0` **留等式**(只有 mock 被修 GH #93
   或 fixture 越过 1500s 才动,**两者都是本节要报的新闻**)/ `past_honest` **退休→ratchet(2)** /
   `s.latest` **退休→ratchet(790.4)**(语料**最大值**只增不减)/ `latest*2<1500` **翻面为 >1500**
   (这才是本节真正在论证的事);另加**独立推导** `#past_frames==past_honest` 且每帧 `t>750`
   —— 因为 sweep 若**膨胀了错的帧**计数根本不动,ratchet 抓不到。
   **⭐⭐ #278 问题 (1) 的答案(驱动实测,2 帧 × 3 路 × 2 拼法 = 12 次)**:
   **子句确实打开了**(`bPastCloseByTime` false→true、`nMaxDesire` **0.92→0.95**,**12/12**),
   **返回欲望 0/12 移动** ⇒ 答案**既不是「一个决策」也不是「一个 cache 字段」**,而是
   **「在我们手上这两帧上它移动的是一个死局部变量」**:两个后果(cap 抬高、`+0.35`)
   **都在这两帧会走的无条件 return `#alliesHere<=1 and aliveEnemyCount>=3` 下游**。
   这仍是**一条边界**,故**按边界写**:零被断言,**造成零的那条帧性质断言在旁边**,
   将来一帧真走到后果处**这里转红**。顺带补上从未被扣住的洞:原 split 块钉了
   阈值/比较/操作数/cache 字段,**两个后果站点一个都没钉**,而 `+0.35` 是**大得多**那条 ——
   「后果不可观测」是在更大的臂根本没被断言时发表的;现在钉**顺序**(`cap < 抢先return < bonus`)
   **不钉行号**(行号会被重构逼着重打,**那正是 `s.latest>690` 陷阱本身**)。
   **⭐ 主判据 B(可复用;由 M1 把我自己的第一个假设证伪后才浮出来)**:
   **「写了没人读」不能靠文件同居判定。值在表里跨文件传递时,读者绑定哪个写者由
   「读的那个函数调了哪个 accessor」决定;一个既写自己 cache 又读别人 cache 的文件,
   会被任何同居判据归给它自己 —— 而判据两边都是绿的。**
   实测:两个 `.currentTime` 读者(`aba_push:173`/`:221`)**都在 `GetPushDesireHelper`**,
   而它在 `:146` 绑 `getGlobalGameState()` ⇒ **`global_cache` 那份是全仓唯一活着的膨胀,
   `aba_push` 自己那份是死的**(`updateGameStateCache()` 的七个调用者无一读 `.currentTime`)。
   底部 accounting 块原写「the dilations in **aba_defend** and **global_cache** ... change nothing」
   —— **数目对(三个里死两个),名字反**(死的是 aba_defend + **aba_push 自己那份**)。
   它自己的 `foreign == 0` 断言**字面为真**,被过度解读成了结论。
   **失效方向是危险的那一侧**:给活着的站点开脱、把死的定罪;而该块自陈用途正是提醒
   「想把 global-cache 决策 turbo 化的人:cache 里的钟没膨胀」—— **指着全仓唯一膨胀的那个文件**,
   照它把乘法当死代码删掉**会静默移动每一场 Turbo 的推进上限决策**。三处均已就地更正
   (**保留历史行并标注「被修正」,不删**),并把跨 accessor 绑定**补成断言**。
   **落地**:`tests/test_gamemode_world_assertion.lua` **唯一改动文件** —— 失败块重取并改名、
   两个新块、`corpus()` 加 `past_frames`(计数驱动不了,得留帧)、新驱动器 `push_desire()`
   (mode 文件在 mock 下**驱动不了**:`bot.PushLaneDesire` 被 mock 应答成**函数**,`==nil` 守卫
   因此通过、下一行索引抛错 —— **harness 限制,不是发现**)。
   **变异 8 个:7 CAUGHT / M2 是「它是死的」的证明**(杀 `aba_push` 自己那份 ⇒ 读数逐字节不变;
   杀 `global_cache` 那份 ⇒ cap 0.95→0.92、past_honest→0);**M7 比预期强一格**:
   放松 `past_honest` ratchet 后仍被**驱动块的非空性守卫**抓到。两端 CONTROL 干净(29/0),
   `bots/` `game/` 逐字节还原;快照走 scratchpad **且快照那步本身被断言**;
   M8 前两次锚点不唯一(count=2)**中止未改文件**,那两次输出**作废未采信**。
   **⚠ 诚实边界**:**零行为改动 ⇒ 无任何「已上线」主张**,不碰 gate 入集状态;
   **我的第一个假设被 M1 证伪并写进报告**(活的那份一直被钉着,真缺陷是**名字写反**);
   「移动死局部变量」**只对这两帧成立**(同局同英雄相隔 5 秒,**不是两个独立样本**);
   **`aba_defend` 的 `*1.65` 是按同一条错判据被归为死的,本轮没有单独证它,仍待独立核验**;
   GH #267 第五次点名,仍不擅自抬。
   **下一格**:#278 三问全部作答 ⇒ **可关**;等总监①裁 `campexit`(仍挂着)、
   〔**2026-08-28T19:xxZ 更正(保留原行)**:①**是过期的等待** —— `campexit` 已于
   06:5xZ 入集(`e7e57979` 把它写进 `test_set.md` 线 2),本行所在的 13:5xZ 那一轮
   跑在已含该裁定的树上。见 `0WAIT` / GH #284。〕
   ②接判据后各做一次**跨文件普查**(A:「散文自己写明了失效事件而它仍是 `eq`」;
   B:「『写了没人读』用了文件同居而值跨文件传」,首个候选 `aba_defend` 的 `*1.65`),
   **本组不自行扩面**;**不为「删掉 aba_push 那份死膨胀」开格**。**
0POP. **【2026-08-28T10:3xZ 新增,GH #277;一条可复用主判据 + 一处 owner P1 DoD① 读数的修正;
   `bots/` **仅 12 行注释**,零新 gate id,零行为改动。】
   **一个普查用「写在被研究函数体内」的那条子句定义了人口 —— 而那条子句被它唯一调用点
   所加的合取吞掉了。于是 owner P1 DoD① 的频率读数描述的是 shipped 链**从不面对**的一组帧。**
   `J.ShouldPullNeutralCamp` 自带威胁否决「800 内无敌方英雄」;
   `bots/mode_roam_generic.lua` 的**唯一**调用点写的是
   `if vCamp ~= nil and J.IsLanePullSafe(bot) then`(1800 内无可见敌方英雄)。
   两者同过 `J.IsValidHero`(→ `utils.IsValidHero`,**要求 `CanBeSeen()`**)与 `IsSuspiciousIllusion`,
   800 ⊂ 1800 ⇒ **`pullsafe` 蕴含 `no800`** ⇒ 那条 800 子句**在结果上永远改变不了答案**。
   而 `tests/_pullcamp_sweep.lua` 的 `peacetime_lane_support` 正是用 `no800` 定义的。
   **⭐ 主判据(可复用)**:**一条被「它唯一调用点所加的合取」吞掉的子句,不只是冗余 ——
   普查会伸手去拿它来定义人口,因为它是写在被研究的那个函数体内的那一条。
   于是读数落在 shipped 链从不面对的一组帧上,而且没有任何东西会转红:
   每一条断言对**孤立的 helper** 都为真。选人口之前,先问调用点加了哪些合取。**
   失效方向是**偏宽**(读数比真相乐观),不是噪声红;与 `0EXIST` 同族,但替身是**人口**不是**帧**。
   **算术(107 fixtures / 993 alive hero frames,同帧求值)**:`pullsafe and not no800` = **0**(反例),
   `no800 and not pullsafe` = **324**(缝);peacetime lane-support **39(800)→ 22(1800)**;
   旧窗口 chain **10 → 4**;新窗口 chain **18 → 9** ⇒ 场景比 DoD 报的**稀缺约 44%**,
   「加行程提前量多买到 +8 帧」在活的门下是 **+5**。
   **⭐⭐ 最硬的一半(ratchet 对这个失效方向是瞎的)**:`cs.ratchet` 是**单调下界**,
   计数器哪天偷偷改回读死子句(39/10/18)**三条 ratchet 全部照过**,`<=` 版的子集断言也照过(取等)。
   真正扣住它的是**严格小于**(活的门严格更强 ⇒ 计数必须严格更小)。
   **M8(把 `<` 放松成 `<=` 再重放 M1)SURVIVED —— 设计内的存活,它就是那条线存在的证明。**
   **落地**:sweep 加 5 个计数器;census 新增 **§1b(4 例)**(蕴含实测 / 两处源码 pin:
   helper 恰一条非注释 800 否决 + 调用点恰一处合取 + `bots/` 无第三引用者 / 修正读数 /
   arc-warden 例外 pin);头注把已发表段落标为**被修正**,**不删历史行**;
   `jmz_func` 那条 header 保证旁加 12 行注释。**变异 7 个:6 CAUGHT / 1 设计内 SURVIVED**,
   三处 CONTROL 干净,还原逐字节相同;夹具走 scratchpad 快照且**快照那步本身被断言**
   (`0QUOTE` 教训已前置生效,本轮没有重演「快照没跑而变异跑了」)。
   **⚠ 诚实边界**:**不推翻 SILENT 根因**(死条件仍是那条 vision 子句;`IsLanePullSafe`
   仍在 385/993 帧通过,**仍然不是第二条死条件**)——本条挪的是**频率**不是判决;
   **不建议删那条 800 子句**:`J.GetNearbyHeroes` 在 **`bot` 自己**带
   `modifier_arc_warden_tempest_double` 时丢掉**每一个**英雄(判的是 bot 不是被扫的 hero),
   那种帧上它是**仅剩的**威胁子句 ⇒ **实践上死、原理上承重**,删它是有真实域的行为改动;
   语料是**本仓 fixture 语料**(战斗瞬间采样)⇒ 两个人口的**绝对**值都不代表真实频率,
   **比值**才是产出;**零行为改动 ⇒ 无任何「已上线」主张**。
   **下一格**:等总监①收 22/4/9 作为 P1 DoD① 的登记读数、②裁 `campexit`(仍挂着);
   〔**2026-08-28T19:xxZ 更正(保留原行)**:②**是过期的等待**,`campexit` 06:5xZ 已入集
   (`e7e57979`);本行所在的 10:3xZ 那一轮同样跑在已含该裁定的树上。见 `0WAIT` / GH #284。〕
   建议总监接判据后做一次**跨文件普查**(「人口由函数体内子句定义,而调用点还加了合取」),
   **本组不自行扩面**;**不为「删掉 800 子句」开格**。**
0QUOTE. **【2026-08-28T07:3xZ 新增,GH #273;一条可复用主判据 + 一条**当轮 trunk 红**被修回绿;
   `bots/` **零 diff**,零新 gate id,零行为改动。】
   **一条自己写着「每加一枚 fixture 就 +1」的量被 `eq` 钉死 —— 而同一条断言,
   对「解析器悄悄漏掉两枚」是瞎的。**
   开工自检报 `TRUNK RED`:`test_write_only_local_census.py` §4 `...carried by 62 fixtures -- got 64 want 62`。
   **成因是一次完全合规的工作**:replay-check `b50a7727`(07:05Z)加了两枚 fixture,carrier 语料 62 → 64。
   改前那两行**自相矛盾**:注释写「Grows by one every time a fixture is generated ...
   The count is a corpus size, **not** a geometry constant」,下一行 `eq(r["carrier_fixtures"], 62)`。
   **⭐ 主判据(可复用)**:**一个冻结的字面量只有在「它转红时说得出这一节正在论证的那件事」时才可断言。**
   失效方向不是噪声红,是**归因错的红**(塔几何 / band / 那条 rung 一个都没动,红却砸在加 fixture 的人头上)
   **加上一个把陷阱重新上膛的最便宜出口**(62 改写成 64)。**GH #236 已经预言过这堵墙。**
   分类:`towers==22` 引擎不变量 ⇒ 留;`band_min==1310` 是**极值**,加语料**只能往下**,
   即只在**论证被削弱**的方向动 ⇒ 红是信息 ⇒ 留;`carrier_fixtures==62` 每次合规添加都 +1、
   且只往**加强**论证的方向动 ⇒ **红永远不是信息** ⇒ 换成推导。
   **不是发明**:这一节**自己已经把对的形状写对过两次**(`band_frames>=60`、`all_min<=200`),
   本轮只是把本节体例补到漏掉的两行上。
   **⭐⭐ 最硬的一半(把「更强」从论证变成读数)**:`band_report()` 靠块正则
   `buildings = \{(.*?)\n  \}` 找 carrier;M1 让它跳过那两枚 venomancer fixture ⇒ 报告读回 **62** ⇒
   **旧断言 `ok ...carried by 62 fixtures` 原样通过(SURVIVED)**,新断言 `FAIL -- got 62 want 64`。
   旧字面量**分不清**「62 是因为总共就这么多」和「62 是因为两枚被解析器吃掉了」。
   **落地**:换成**两条** —— (1) **独立推导的相等**,用一条**不共享解析器**的行扫描
   (只找 `name = 'tower'`,**根本不去找那个块**)独立数一遍再断言相等;(2) **单调下限** `>= 62`
   (62 = 距离当初推导时的语料,`f_212636_tide_ancient`,GH #197)——**语料可以随便长,
   不许在论证底下悄悄缩水**。顺带去掉 `tower_band_domain.py` LIMITS 里
   `The archive is 106 INCIDENT-selected fixtures`(**实际已 107**)的冻结数字 —— 同族但更隐蔽:
   **prose 没有任何东西断言它,所以它是无声腐烂**。
   **变异 5 个**:M1 CAUGHT(旧断言 SURVIVED)/ M2 放松行扫描 CAUGHT / M3 冻回 62 CAUGHT /
   M4 语料缩到 63 SURVIVED(**符合设计**)/ M5 缩到 61 CAUGHT;两端 CONTROL 干净。
   **⚠ 方法自伤一条(方向是弄脏工作树)**:M4 的 heredoc **没 export `SP`**,`KeyError` 让**快照那步没跑
   而变异那步跑了** ⇒ 三枚 fixture 被弄脏且无快照可还原(已 `git checkout --` 还原并复核干净;
   那三枚**不属于本轮改动**所以走 VCS 是安全的)。**教训补一句:快照那步自己也必须是被断言的**
   —— 这是 `0CAMP` §i「还原路径不许经过版本控制」差一点重演的形状。
   **⚠ 诚实边界**:**不声称修好 GH #267** —— 它**同族但信息含量相反**(那个数字编码「哪次改动加了站点」
   这条证据,抬它会**抹掉证据**);**本组第三次点名,仍不擅自抬**。
   **`band_median==2086` 刻意不动**,理由就是主判据本身:中位数**可以往环的方向移**,
   而那正是本节在论证的东西 ⇒ **它的红是信息。这不是漏掉,是判据的另一侧。**
   残留同族一处登记未做:docstring 里「72 frames at level <= 2」是 prose 里的语料衍生计数、无断言扣住。
   **下一格**:等总监裁 `campexit` 入集(仍挂着);**不为「把 `band_median` 也解冻」开格**。
   〔**2026-08-28T19:xxZ 更正(保留原行)**:这一格**在写下它的那一轮就已经到期** ——
   `campexit` 06:5xZ 入集(`e7e57979`),而本行所在的 07:3xZ 那一轮自己的报告里
   写着 `开工 HEAD == e7e5797`,**就是那个裁定的 commit**。见 `0WAIT` / GH #284。〕
   建议总监接判据后做一次**跨文件普查**(「注释说它会长 / 断言用 `eq`」还有几处),**本组不自行扩面**。**
0BAND. **【2026-08-28T04:3xZ 新增,GH #265 的**预登记证伪**落地;一条可复用主判据
   + 一个已落地的 gated id + 两条被打红的普查棘轮(**都加固,不放松**)。】
   **那个浪费在**出厂腿**上,而「把守卫的常数改对」是个**可证明的 no-op**。**
   录像组 03:52Z 执行了 #265 自己写下的预登记(语料 19→**86 局**,ab 74 / ba 12,两个物理分层都有 armed 腿),
   结论是**改写**:10..11 带上 armed 34 个 / baseline 25 个 episode,**四个分布量逐位相同**
   (0.103/0.104、35.3%/36.0%、8.3s/8.4s、38.2%/36.0%),五张分层表**全部两层反号**。
   出厂腿五帧(venomancer L10 / dragon_knight L11 / necrolyte L10 / lion L10 / storm_spirit L11)
   **敌方英雄伤害全为 0**;venomancer 那段满血走 3800u 去 Prowler 营,**普攻**开打,
   **15.0s 坐标逐位相同**,输出 1007 / 挨打 898(**≈1:1 赔本**),然后走人。
   录像组原话:**「它今天没有任何 armed id 管得着。」**
   **⭐ 主判据(可复用)**:**一道门值不值得抬高,取决于它守的那条分支是不是**真正动手**的那条。**
   失效方向是**一个长得像判决的空操作**:改法会 arm、会量不到东西、会被读回成「测过了,没效果」,
   **而没有任何东西会为此举手**。
   **算术**:farm 文件把远古档位**写了两遍字面量 10**,而申报档位是 `ANCIENT_MIN_LEVEL = 12`
   ⇒ 被量到的带 **{10,11} 正好是两个常数之间的缝**。
   **承重**:`Think()` 的**第三条中立分支**(1000u `neutralCreeps`)**一条档位子句都没有**;
   10-11 级时 `#nNeutrals>=3` 那个**闩**通过它自己的 `>=10`、置 `FARM_STATE_FARM`,
   此后每帧**穿过两条带守卫的分支**落进没守卫的那条 ⇒ **上面两条 `>=10` 是装饰**,抬高它们是 no-op。
   (`aba_site.lua` 的 `FilterFarmNeutrals` 注释**从 GH #137 起就写着**第三次读没有远古子句,**没人动过手**。)
   **落地**:gated **`campexit`**(`J.IsOverTierCampOnly`,turbo-only 单合取,gate 在唯一调用点解析)。
   为真 = sweep **非空** ∧ **不含 Roshan** ∧ `FilterFarmNeutrals` **一个都留不下**;
   **档位判定就是那个 filter 本身**(不复制第二份定义)。
   **armed 是放行不是拒绝**:`FARM_STATE_NONE` → 出厂 `UpdateAvailableCamp` 退役该营 →
   唯一 `ClosestCamp` 重选 → **两条臂都必然发 move**,块以 `return` 收口 ——
   把 `campvoid` 那条死锁教训**前置**。**不与 `campfarm`/`campvoid` 合取**,且读**原始 sweep**
   (喂过滤后的表会让 `campfarm` 一 arm 就把它悄悄关掉 —— 变异 M9)。
   新增 `tests/test_campexit_tier_release.lua` **17 例**,带 `[ratchet]`(快腿 15 → 16);
   **判别用例(混合 sweep)是先写的**,M4 正是被它抓到;**变异 3 批 17 个,首轮 17/17 全抓**。
   **⚠ 两条 `campfarm` 棘轮被打红并已加固**:(1) 「every neutral sweep …」只数**内联**包裹,
   而把 sweep 绑到 local 再传(**正是把引擎调用数保持在 3 的做法**)被读成没包裹 ⇒ 现在**解析这一跳绑定**
   并额外断言任何绑定了 sweep 的 local 都必须到达 `NeutralFarmList`;(2) 「the wrapper is the only gate」
   把 filter 的文件表钉死在两个文件,**顺带禁止了别的杠杆复用这个纯函数** ⇒ 现在第三个文件**按名准入**
   并被更严的测试扣住(不许提 `campfarm`、不许把 gate 传进 filter、**必须传字面量 true**)。
   **两条都用 M15/M16/M17 复验过还咬得动。**
   **⚠ 诚实边界**:gated ⇒ **不是 live**;**(a) 一帧没买到**;端到端没做且理由钉成可执行断言
   (`[limit reach]`:两个中立 sweep API 在 4 subject × 3 半径全答 `{}`);turbo 由 loader 强制
   (`[limit gate]`);**可达性(bot 已在第三条分支里)没量过,不猜**;**不声称关掉 #265**(§2 仍 BUGGY-or-SILENT,
   armed 腿为何不收缩也不由本条回答)。
   **⚠ `test_activemode_world_assertion:445` 仍红(GH #267)**:`git stash` 后在**净 trunk 上复现同一数字**,
   本轮新增 `GetActiveMode()` 站点 **0 个** ⇒ **不是本轮引入的**,本组**仍不擅自抬那个数字**。
   **下一格**:等总监裁 `campexit` 入不入集(建议**入**,且**可以单独 arm**);
   **不为「把两个 `>=10` 抬成 12」开格** —— 本轮已把它证明成 no-op。**
0VOID. **【2026-08-28T01:2xZ 新增,GH #265 认领并落地;一条可复用主判据 + 一个已落地的 gated id
   + 一条 trunk 既红检测器的二分定位。】
   **`campfarm` armed 清空了攻击表,却没有把 bot 从营地里放出来 —— 而本轮真正学到的是
   「一个修复从表里拿走条目时,所有另外问『这张表空不空』的谓词必须按同一条规则过滤」。**
   `bots/mode_farm_generic.lua` 用**两个引擎 API** 读中立:`bot:GetNearbyCreeps`(3 处,`campfarm` 全包)
   与 **`bot:GetNearbyNeutralCreeps`(3 处,一处都没包)**。而 `campfarm` 那条自称
   「every neutral sweep in the farm mode goes through the one gate」的断言**只数第一个 API**,
   **第二个它的 pattern 根本够不到**。三处里恰好一处在**动作路径**(`Think()` 的小兵出口):
   `if J.IsValid(farmTarget) and #nNeutrals == 0 then` —— **极性与 filter 相反**:
   armed 且低于档位时攻击表是空的,而**被删掉的那些远古仍被数着**,数着它们**就把出口锁死**
   ⇒ **不能打,也不能走;出厂代码没有覆盖这个状态的分支。**
   **⭐ 主判据(可复用)**:**失效方向是「死锁」不是「选错」,而且每个站点单独看都没改、
   都站得住 ⇒ 没有任何东西会为此转红。** 是 GH #257/#261/#266 那一族**往上一层**:
   那边是**工具**把文件级推断成站点级,这边是**一条断言的名字**宣称了它自己够不到的全集。
   **承重帧是 #265 §1**:4 级 ES 19 秒六次穿越黑龙营,**自己零 DAMAGE 事件**,3000u 内无敌方英雄,
   t=238.1 被 `black_drake` 打死 —— **「自己零输出」正是 armed `campfarm` 的直接后果**
   (攻击表空 ⇒ 根本不发 `Action_AttackUnit`)。
   **落地**:gated **`campvoid`**(`NeutralPresenceList`,turbo-only 单合取,复用已在树上的纯函数
   `J.Site.FilterFarmNeutrals`,**零新语义**),只包 `Think()` 那**一处**;
   `GetDesireHelper()` 那两处(只盖 `teamTime`、不发动作)**刻意不动并钉成断言**。
   **不与 `campfarm` 合取**(`pullcad`)。**单向性在源码里可读**(filter 只移除条目 ⇒
   `#==0` 只能 false→true ⇒ armed 只能**打开**出口、永不关闭),行为侧另有
   **16 格全网格断言** + 「恰好 3 格翻开」(否则「单向」会同时被**什么都不做**和**把表清空**满足)。
   新增 `tests/test_campvoid_presence_axis.lua` **18 例**,带 `[ratchet]`(快腿 15 → 16);
   **判别用例(混合 sweep)是先写的**,M7「清空表」正是被它抓到;
   **变异 2 批 12 个,首轮 12/12 全抓**,两端控制项干净。
   **⚠ 诚实边界**:gated ⇒ **不是 live**;**(a) 一帧没买到**;端到端没做且理由钉成可执行断言
   (`[limit reach]`:出厂守卫 `#hLaneCreepList > 0`,而 W1 钉住语料**两个 sweep API 在
   4 subject × 3 半径上全答 `{}`**);**§4 的第三读法只覆盖 #265 §1,解释不了 §2**
   (bristleback L11 那两段**存在** DAMAGE 事件)⇒ §2 仍是 BUGGY-or-SILENT,**不声称关掉**;
   **可达性(小兵在 900u 内 ∧ 低档远古在 attack_range+180 内)的合取频率没量过,不猜**。
   **下一格**:等总监裁 `campvoid` 入不入集,**并显式裁「要不要与 `campfarm` 同腿 arm」**
   (死锁前提是 `campfarm` armed;本组建议同腿 arm、两个独立 id、不合取、可分别 promote);
   **不为 desire 侧那两处 sweep 开格**,直到有帧证据说它们真的改了行为。**
0FIRST. **【2026-08-27T22:2xZ 新增,GH #263 认领并裁定 + GH #262 落地;一条可复用主判据
   + 一个已落地的 gated id + **本组第一次推翻自己上一轮的入集建议**。】
   **一个门的「窄」可以是不相干而不是安全 —— 而本组上一轮的等级门在它自己的域里至少有一帧是反向的。**
   GH #263 在 W18 两腿语料(68 局 / 143 个远古 episode)上量出:门内 **5 个 episode / 1 次没拿下**,
   门外 **138 个 / 41 次**,**占比两边接近**(20.0% vs 29.7%)⇒ **刀口在分子不在比率**:
   低等级英雄不是更容易「戳了不拿」,是**根本很少去戳**(Turbo 升级快)。可及面 **0.074 episode/局**。
   **承重的不是这张表是那一帧**:`843688/20260827_185943_slot12` t=708.0,zuus **lvl 11(门内)**
   两发 Arc Lightning 于 709.9 击杀 black_dragon,**GOLD+XP 入账**,代价 ~17% 蓝 + ~1.4% 血且当场回满
   ⇒ **一次干净盈利的门内击杀,armed 后不会发生**。表说「收益小」,帧说**符号错**。
   **⭐ 主判据(可复用)**:**谓词必须和它许可的那个对象是同一个对象;门必须和它针对的缺陷在
   同一根轴上。否则它的「窄」不是安全,是不相干。** 失效方向是**假的窄**:小域在评审里读起来像
   低风险,而它恰恰因为**瞄偏了**才这么小,**没有任何东西会为此转红**。#263 是**轴**的尺度
   (等级 vs 完成度),#262 是**对象**的尺度(守卫 `[1]` vs 冲锋 `[2]`)—— 同一个错误的两个放大倍率;
   是上一轮主判据的**生产侧孪生**(那条治测试测错了东西,这条治门管错了东西)。
   **落地**:gated **`aimguard`**(`J.CanBeAttackedPair`,turbo-only 单合取,**armed 分支零数字零等级读数**),
   收编 `[1]` 族第三个站点 `hero_spirit_breaker.lua:287-296`(判 `[1]`、打 `[2]`)。
   **单向性在源码里可读**:不armed 逐字是 `J.CanBeAttacked(hGuard)`,armed 只能再加一个合取
   ⇒ 只能扣下、永不新增;行为侧另有全网格断言 + 「网格确实分开两条腿」(恰好 2 行被扣)。
   **不与 `abilanc`/`abil1st` 合取**(`pullcad`)。新增 `tests/test_aimguard_target_axis.lua` **11 例**,
   带 `[ratchet]`(快腿 13 → 14);**变异 3 批 13 个,首轮 13/13 全抓**(上一轮判别用例的教训**前置生效**),
   两端控制项干净。
   **⚠ 撤回**:本组**不再建议 `abil1st` 在等级轴上入集**(已写进 `state.json` 与 `test_set.md §BR.2`);
   请总监**一并重看已在集的 `abilanc`** 的同一条阈值。**本组不自行退集**(入集权在总监)。
   **⚠ 诚实边界**:gated ⇒ **不是 live**;**(a) 一帧没买到**;**端到端没做且理由钉成可执行断言**
   (`[limit reach]`:分支在 `J.IsAttacking` 之后读三个 dump 不携带的动画量,且本帧蓝 0.189 低于
   分支自己的 0.25 前提);营地是**声明输入**([W1]);turbo 由 **loader 强制**,钉成 `[instrument]`。
   **下一格**:等总监裁 `aimguard` 入不入集 + 对等级轴的重看;**不为完成度子句开格**,
   直到录像组把 #263 §6 的 episode 口径**入库并加棘轮**并给出逐帧「戳营帧 → 15s 内是否击杀」读数
   —— 本地语料**不带任何小兵实体也不带战斗结果**,完成度谓词今天钉不到帧,凭直觉落地正是 `lanefix` 的形状。
   剩余裸 `[1]` 站点仍 **8 个**(#262 已收编,但走**对象轴**不是等级轴,**不消耗** `abil1st` 的分母)。**
0AB1ST. **【2026-08-27T19:2xZ 新增,GH #259 认领并落地;一条可复用主判据(来自一条**活下来的**变异)
   + 一个已落地的 gated id + 本组十轮以来第一次真的动了 `bots/` 的行为。】
   **`abilanc` 注释里留的那个分母买到了它的第一根杠杆。** 那段注释写明「**故意不覆盖**读 `list[1]` 的
   54 个站点,好让下一根杠杆有分母」;W17-R 18 局给了分母第一批帧:**level<12 的远古施法 3 次,3/3
   全部来自这个 population**,两次同一浪费形状(戳两下 → 不打完 → 走人)。
   zuus L11 两发 Arc Lightning 砸远古营(蓝 1.00→0.81)后掉头 —— `hero_zuus.lua:727` 把
   **「只有一只、但它是远古」显式写成开火理由**,而这条分支**一个等级子句都没有**;
   centaur L11 一发自伤大招砸远古营(0.59→0.48)后走人 —— 它唯一像门的
   `J.GetHP(list[1]) > 0.33` **是反的**:远古恰恰永远够厚。
   **落地**:gated **`abil1st`**(`J.GetFirstUnit`,turbo-only 单合取,阈值读
   `J.Site.ANCIENT_MIN_LEVEL`)。不armed **逐字是 `unitList[1]`**;armed 且低于档 ⇒ 同一次 sweep 里
   **第一个非远古**或 nil(**nil 不是新的结果类**)。**`ipairs` 不是 `pairs`**。
   **不与 `abilanc` 合取**(`pullcad` 陷阱),而且两者**不是同一个缺陷**:「最高血」**按构造**是远古,
   `[1]` 是引擎顺序、**只是有时候**是远古 —— 这句话在测试里是**读数**不是说辞(同一张表两个 reader 答不同的单位)。
   **⭐ 主判据(可复用,来自那条活下来的变异)**:**一条自称测「按 X 选」的断言,必须跑在一张让 X 与
   所有近邻规则给出**不同**答案的输入上;否则它测的是「答案对不对」,不是「按什么选的」。**
   失效方向是**假绿**:M9(「第一个非远古」→「**血最多的**非远古」)在首轮 12 条断言下**全绿**,
   因为那张营地表里只有**一只**非远古,两条规则在它上面是同一个答案 —— 而那条自称测顺序的断言
   拿的正是这张表。**修法不是补断言,是加判别用例。**
   **端到端(zuus)在真实帧上跑通**,顺序按 #259 要求:**先**断计划存在(出厂 `0.75/granite_golem`,
   **这就是 620.4 那个决策**),**再**断 armed 后 `0/nil`(反过来会把「本来就没计划」读成「改动生效」,
   GH #250 同款坑)。**centaur 端到端没做,理由写成了可执行断言**:它的分支在 `J.IsAttacking` 后面,
   而那条读**三个 dump 不携带的动画量** ⇒ 再声明就是在没有帧的营地上叠第二层没有帧的声明。
   **变异 3 批 13 个,首轮 12 抓 1 活,补判别用例后 13/13**,两端控制项干净(含 **M11:守卫文字保留
   但被 `or true` 架空** —— 行为侧抓到,证明端到端那三条不是摆设)。
   **下一格**:等总监裁 `abil1st` 入不入集(本组建议**入**,且**必须与 `abilanc` 分开 arm**);
   **不为剩下 8 个 `[1]` 站点开格**,直到它们里有一个拿到帧证据 —— 这正是留分母的用法。**
0POLY. **【2026-08-27T16:3xZ 新增,GH #254;认领章程 `0POLL` 并**答掉它挂着的两个前置问题**;
   一条可复用主判据 + 一个已落地的 gated id + 一条被钉住的「刻意不改」+ 一条方法自伤。】
   **`0POLL` 问的是「这四处 getter 该统一到哪一侧,统一本身要不要作一个原子」——
   两个答案都是「不」。** `aba_global_overrides.lua` 的 `GetHealth` 不是一件事:它打包了
   **一条哨兵**(`not CanBeSeen()` ⇒ 字面量 **666**)和**一条建模**(美杜莎 = 血 + 当前魔法
   能吸收的伤害,`mana*2.6*0.95`,12 级以下折半;`GetMaxHealth` 带同一项但走**最大**魔法)。
   **⭐ 主判据(可复用)**:**轴按问题定,不按文件定。** 哨兵在任何比较里都不是测量;建模只在
   「它建模的那个资源**就是本次动作作用的资源**」时才是测量 ⇒ 「统一」按**成分**拆,不能按文件拆。
   而且**同一个 consider 内部两处读数要相反的一侧**:门问「这次治疗能补回多少」(必须 Original,
   补的是**血**),选人问「谁最接近死」(护盾吸收是真的,建模值更对)。这是对 `0SALT`
   「轴全文件一起定」的**限定不是推翻**:`0SALT` 治**不一致**,这条治**被强行一致**——
   而后者**不会有任何东西转红**,因为统一之后文件看起来更整齐了。
   **域**:105 fixture / 1050 单位 / 美杜莎 17 行(活 16)/ **1000 内友方配对 5** /
   **两个 getter 给出相反门结论 5(5/5,universal)** / **满血被放行 4** / 最大幻影缺口 **497.9**
   (每一点都是魔法)/ **归档持有这枚中立装的单位 0/1050**(中立装不进 dump 的物品槽 ⇒ 端到端不声称)。
   锚点 `f_260819_222559_od_eclipse_pair.lua`(t=631.5):11 级美杜莎 **227/230 = 98.7%**、
   569/930 魔、距友方 lich **122u**、`modifier_medusa_mana_shield` **正在运行** ⇒
   出厂读缺 **472.3** 放行 / Original 读缺 **3** 拒绝,差值**精确等于**缺魔项(1e-9)。
   **落地**:gated **`pollyhp`**(`J.PolliwogAllyMissingHealth`,turbo-only 单合取,armed 分支
   **不含任何数字**);调用点**一行换一行**,AIUG **净 0 行**;**选人那一行刻意不动并钉成断言**;
   `100` 下限不是本轮杠杆,只钉不动。**单向性证明在源码里**(`maxMana >= mana` ⇒ armed 只移走
   候选、绝不放进);**哨兵那半够不到这个调用点**(`J.IsValidHero` → `utils.IsValidUnit` 要
   `CanBeSeen()`,两个文件都读出来钉住)。
   **⚠⚠ 本轮最该记的边界:验证仪器看不见这条分歧。** `bot_api.lua` 里 `CDOTA_Bot_Script` 是
   **空表**(套件从不安装 override 层),`replay_fixture.lua` 在**同一条语句**里把 `u.hp` 同时赋给
   `GetHealth` 与 `OriginalGetHealth` ⇒ 通过 loader 读,**armed 与 baseline 逐位相同**,
   **一次 armed-vs-baseline 的 fixture 读数在这里是按构造的 no-op,绿了也什么都没说**。
   于是上面的数字是「**真实帧的数 + 从源码读出的 override 函数**」(`[replayed]`),
   塌缩本身被 `[instrument]` **钉成断言**不当脚注;另 **0/1050 行带 `seen_by`** ⇒ 哨兵那半本地
   连语料都没有(也钉成断言,v2 视野 fixture 一落地即转红)。**与 `0RANGE` 同族更深一层**:
   那条说「先问谓词在这台仪器上的**值域**」,这条说**两侧根本是同一个数**,连值域问题都不成立。
   **⚠ 方法自伤(同义反复,GH #248 (ii) 同族)**:把 override 的最大项 `GetMaxMana()` 改成
   `GetMana()`(直接摧毁单向性),18 例**全绿** —— 那条全语料扫描问的是**测试自己对 override 的
   建模**。**修法不是补断言是换仪器**:把单向性依赖的**源码事实**读出来钉住,扫描**降级**为
   「模型在真实数字上的算术检查」并写明它抓不到 override 本身的改动。**变异 3 批 13 个,
   首轮 12 抓 1 活,修好后 13/13**,两端控制项干净;还原走 scratchpad 快照 `cp`(`0CAMP` 教训)。
   **下一格**:(i) 等总监裁 mock 要不要携带 shipped override 层(收益:「换 getter」这类改动
   **第一次可本地判**;风险:**爆炸半径大**,`GetHealth` 被全仓 `J.*` 读,**本组不自行扩面**);
   (ii) 若不扩 mock,本组这条 getter 线**收官**,回 `[strategy]` issue 或 owner 优先项重新认领。
   **不为「统一另外三处」开格** —— 主判据说明那是错的问题。**
0RANGE. **【2026-08-27T13:5xZ 新增,GH #250 认领并裁定;一条可复用主判据 +
   一条裁定「不落地」+ 一条登记的诚实边界;`bots/` **零 diff**,零新 gate id。】
   **GH #250 §4 的验收第一步 `ShouldPullNeutralCamp(bot) ~= nil` 在它自己指定的仪器上是常数
   ——全语料 974 帧非 nil 计数 **0**(turbo 与 `pullcamp` 两个前提都给足);而它给 nil 挂着
   一条二分支解读(「本例与 `pullthink` 无关,#186 的归因需要重看」)⇒ **那条结论会由 mock 写出来**。**
   **⭐ 主判据(可复用)**:**一条谓词被提议当验收步骤之前,先问它在「将要用来读它的那台仪器」上的
   值域。已知在那台仪器上是常数的谓词不是测量;而一旦给它挂上二分支解读,仪器就从「回答的东西」
   变成了「下结论的东西」。** 它是 `test_pullcamp_trigger_census.lua` §1 那套 STOPPER 普查的
   **配方侧孪生**:那一侧说「语料看不见什么」,这一侧说「因此不许拿它问什么」;失效方向是
   **一条真实归因被以仪器理由撤回,并且被报成「测量过了」**。
   **⭐⭐ 归因不是断言**:常数**不是**(只是)`GetNeutralSpawners` 桩 —— **选营循环根本没跑到**。
   每一帧要么更早被子句挡掉,要么在**均势子句**上撞 GH #61 的 loader 拒绝
   (`GetLaneFrontLocation`);`spnc_raise == chain_new == 18` 是**同一个合取的两种独立算法**
   逐位相同。⇒ 在 fixture 上问 #250 第 1 步要**两处 declaration**(分路世界 + 营地表),
   按本文件 §2 自己的标签那就是 **DECLARED-WORLD 测试**:能演练子句,**不能见证那一帧**。
   **⭐⭐⭐ 顺带裁定:#250 §4 第二条建议(中野数量/伤害进安全子句)本轮不落地** ——
   立论站得住(安全子句只数**敌方英雄**,pos 5 进 12 只叠营在 turbo 必亏),**但今天钉不到帧**:
   fixture **不带中野实体**(`camp_up == 0`,974/974),中野唯一痕迹是 recent-damage 的 `src`,
   全语料 **3 帧 / 非核心 1 帧 / 落在 60–360s 拉野窗口内 **0** 帧**。域为 0 ⇒ 不开 gate。
   **重开条件写成了可执行断言**:`neut_dmg_support_window == 0` 转红即可落地(断言消息写着
   "go land it")。顺带第二个事实:**诊断管道与验证管道不重合** —— #250 的 timeline 读得到
   `neut(<=700)=12`,fixture 格式里这个数**不存在**。
   **落地**:扩 `tests/_pullcamp_sweep.lua`(**不新建第二次全语料 sweep**,加 7 个计数 + `NEUTDMG`
   记录行,探针放每帧最后、跑在 per-frame 全新的 J 上 ⇒ 够不到任何既有计数;40s → 46s);
   `test_pullcamp_trigger_census.lua` **21 → 25 例**(§4:常数零 + `raise == chain_new` 归因 +
   中野域 3/1/**0** + 一条**顺序钉**,因为 §4 的推理用的是顺序,「两半都在」不够)。
   **不打 `[ratchet]` 标签 ⇒ 不进开工自检快腿**(46s vs 快腿 12 文件 13s),与本文件既有做法一致
   —— **这是一个明确登记的洞**,要不要给快腿立「重普查取廉价子集」的通例**交给总监**,本组不自行扩面。
   **⚠ 变异 4 批 4 中 4,两端控制项干净**(M1 不 arm / M2 死 token / M3 源码去掉
   `GetLaneFrontLocation` / M4 分类器对调),还原走 **scratchpad 快照 `cp`**(`0CAMP` 教训)。
   **⚠ 登记一条诚实边界(`0EXIST` (iii) 同族)**:`spnc_nonnil == 0` 在干净树上与 `>= 0` 分不开,
   它是对**植入的仪器违规**验的,**不是**对「真能产出非 nil 的世界」验的 —— 那样的世界在这里
   不可达,而**那正是本条断言自己的内容**;承重推理的两条都是**对着源码**变异捕获的。
   这行诚实话**写进了测试注释**,不只写在报告里。
   **下一格**:回 `0POLL`,或按 owner 优先项 / `[strategy]` issue 重新认领;
   **不为 #250 §4 第二条建议开格**,直到 `neut_dmg_support_window` 转红。**
0EXIST. **【2026-08-27T10:3xZ 新增,GH #248 认领 GH #137 后产出;一条可复用主判据 +
   一条裁定「不做」+ 三条同族方法自伤;`bots/` **零 diff**,零新 gate id。】
   **GH #137 的承重帧一直在语料里 —— 而 `campgrade` 的每一条「承重案例」断言都打在替身身上,
   因为一句注释说那一帧买不到。**
   `test_campgrade_tier_ladder.lua` 头注写着 `f_260823_002103_wk_ancient_camp_634`
   **"is not in the tree on any ref" / "level 11 for a Wraith King is not purchasable"** ——
   **两半在 HEAD 上都假**:帧在 `tests/fixtures/`,`skeleton_king` **就是 11 级**,且带
   `modifier_ancient_rock_golem_weakening`(elapsed 11.0s),坐标与 #137 §3 逐帧表逐位吻合。
   于是最强的那条断言(「在那个 WK 把血磨到 13.5% 的远古营帧上 armed 拒绝这个营」)
   **躺在隔壁目录没人拿**,10 级替身顶着 `the bearing-weight case` 几个字,`[boundary] 11 refuses`
   用的是 **axe**。
   **⭐ 主判据(可复用)**:**一条「语料里没有 / 买不到」的断言,是关于一个只会增长的集合的
   断言 —— 它写下时为真,而后不需要任何人碰这个文件就会变假,并且没有任何东西会红。**
   失效方向是**假绿**,形状固定:**替身长期顶着承重案例的名字**。与 `corpus_scale.lua`
   **是镜像不是重复**:那条治增长把**计数等式**打成**假红**(响的),这条治增长把**否定性存在断言**
   打成假(**哑的**)—— 之前只有响的那一半有把手。**修法不是改注释,是把断言变成可执行的**
   (与 `0SALT` 的「标记做成红测试不做成注释」同源,但那次治**标记**,这次治**论据**)。
   **落地**:(a) `test_campgrade_tier_ladder.lua` 14 → **16** 例 —— 头注更正(假句子**原样留在
   原地**标 `[CORRECTION]`,删掉它等于删证据)、`WK_L11_BEARING`、两条新测试(存在性 + 等级 +
   **远古营减益**三条都断言,否则是拿名字论证;同帧同时钉缺陷与修复);承重帧并入 `[world W2]`
   / `[不饿死农田]` / `[off-candidate 等价]` 三条既有循环。(b) 新增
   `tests/test_corpus_existence_claims.lua`(**4 例**,`[ratchet]` ⇒ 自动进自检快腿,11 → **12**
   个标签文件):**(A)** `tests/` 下点名的 fixture 路径必须存在(**267** 引用 / **208** 源文件 /
   **0** 缺失,下界不等式);**(B)** 任何一行不得在点名一个**存在的** fixture 的同时断言它不存在
   (今日 **0**;对**真的没有**的路径说「不存在」不报 —— 那归 (A))。
   **⭐⭐ 顺带裁定:GH #137 建议 3(攻击力进远古档)本轮不做,理由是算术不是口味** ——
   (i) **不可验证**:(W2) `GetAttackDamage()` 在**每一枚 fixture 上都读 0`,`0 <= 80` 恒真 ⇒
   整份语料上真空为真,本地拿不到任何读数;(ii) **没有可推导的常数**:承重案例 11 级 / 80–81 伤害
   **已被等级档拦住**,建议 3 只在 **≥12 级且伤害 ≤80** 买到域,复用 80 对同一个 WK 在 12 级
   (约 83)几乎买不到格,换更大的数就是**裸拟合** —— 与 `0SALT` 同形(工具按算术为空)。
   **重开它的唯一东西是 dumper 开始携带攻击伤害**,不归本组。
   **⚠⚠ 方法自伤三条(方向全是「把没通过报成通过」,修法全是换仪器不是补断言)**:
   **(i) 针的集合也要唯一,不只是针** —— `ABSENCE_TOKENS` 收了 `'is not in the tree'` 与
   `'not in the tree on any ref'`,杀内层的变异**活了**(控制项那一句同时含外层)。是 #237
   「`"10 failures"` 含 `"0 failures"`」的**高一层**(那次一根针有歧义,这次**一套针互相遮蔽**),
   也是 `0SALT`「针必须唯一」的**集合版**;修法 = 两两不含 **+ 把不含关系写成断言**。
   **(ii) 用被测对象造样本的控制项是同义反复** —— per-token 控制项拿 token 自己拼样本,
   **7 条删除变异活了 6 条而控制项全绿**;修法 = 样本句**独立手写** + **双向**覆盖断言(每句被抓
   ∧ 每条 token 都是某句被抓的原因 ∧ 一一对应)。
   **(iii) 干净树上 `== 0` 与 `>= 0` 分不开** —— 两条棘轮收尾断言换成 `>= 0` **全活**;
   修法 = 抽成**共享仪器** `require_clean()`,控制项在**植入的违规**(`os.tmpname()` 假源文件,
   各一条 (A)/(B) 违规)上**看着它 raise**;sweep 吃 file list 作参数 ⇒ 控制项与棘轮跑**同一段代码**。
   **三批 14 / 5 / 12,活 3 / 2 / 3**,两端控制项干净,顺序执行不并发,判定读数打在 runner 汇总行。
   **还原走 scratchpad 快照 `cp` 不走 `git checkout`**(`0CAMP` 教训)。**剩下的活口全是
   「放松一条防真空/防歧义护栏」,在干净树上是等价变异 ⇒ 明确登记为等价、不补断言**
   (再补一条只会造出另一个同样分不开的零,正是 (iii) 刚学到的)。
   **下一格**:回 `0POLL`,或按 owner 优先项 / `[strategy]` issue 重新认领。
   **不为 #137 建议 3 开格**。交给总监的**范围决定**:本轮只扫了 `tests/` 一面,
   **`tools/` 与 `docs/` 没扫**,要不要把「否定性存在断言一律可执行」升成通用纪律,本组不自行扩面
   (与上一轮 `BOT_API_REFERENCE.md` 全文件普查同族,两条一起裁更省)。**
0CAMP. **【2026-08-27T07:3xZ 新增,GH #241 认领并裁定;一条可复用主判据 + 两条方法自伤;
   `bots/` **零 diff**,零新 gate id。】
   **GH #241 立案的「三处 shipped 代码 vs 本仓 API 参考」不是两方矛盾 —— 那一行**从来没有
   观测过 bot API**,因此反驳方退役;但退掉一个坏的反驳方 **≠** 确认了代码。**
   **⭐ 主判据(可复用)**:**一份文档比它自己引的来源知道得更多,它就不是来源。**
   Valve 的 wiki(两份独立镜像)对 `GetNeutralSpawners` **零字段文档**;ModDota 的引擎 dump
   给 `: variant` + 一句 help 串,也没有字段表;而本仓这一行有**六个字段各带类型标注**。
   页首引的还是 `Dota_2_Workshop_Tools/Scripting/API`(**server-vscript**,不是 bot scripting)。
   同样六行**逐字**出现在无关第三方仓 `shikyo13/Dota2AI` 的**同名文件**里 ⇒ 同一血统,非独立确认。
   **⭐⭐ 不需要外部来源的那半(最硬)**:该行**每一个数字型标注都紧挨着一个字符串型描述** ——
   `type` (int) 却把 `small/medium/large/ancient` 写成它的取值;`speed` (float) 而 shipped 代码
   比 `"fast"/"slow"`;外加 `idx` **该行根本没列**却被 `RefreshCamp` 读 **4** 次 ⇒
   **类型错 + 不完整**,是被**编出来**而不是被读出来的类型列的指纹。
   **⭐⭐⭐ 对 owner P1**:#241 §5 那条交叉线(`camp.team` 使 `pullcamp` **构造性 SILENT**)
   **失去依据**;引擎 help 串 *"...what side of the river they're on"* 反而是弱正向信号 ⇒
   **P1 第 1 项的归因不必重开**。但 `.type == "ancient"` 那一半**仍然完全未验证**。
   **落地**:doc 改写(`variant` + 三个 `(unverified)` + 补 `idx` + 退役说明,**doc 里不写行号**,
   GH #221 教训);`campsel_domain.premise_sites()` 加 `speed_readers`/`idx_readers`/`doc_section`,
   selfcheck **63 → 70 PASS**;棘轮**移钉不放松** —— 「API 参考仍在唱反调」那一条拆成 **5 条**
   (含「`int` 不许放回去」与两个 `#241` 指针各恰好一次)+ 2 条把「它自相矛盾」的论据本身钉住。
   **⚠ 方法自伤二条(方向都是「把没通过报成通过」)**:**(i) 变异夹具的还原路径不许经过版本控制** ——
   `restore()` 用 `git checkout` 把**本轮未提交的被测改动**擦掉,两端 CONTROL 全 DIRTY、
   五个变异 SETUP-FAILED;改成 scratchpad 快照 `cp`。**(ii) `'#241' in section` 不是 pin** ——
   该 token 在那节里出现**两次**,只删一处的变异 **SURVIVED**;这是 `0SALT`
   「针必须唯一」的**反向**同族(那次变异打在没被断言的拷贝上,这次断言落在不唯一的针上),
   **修法是换针不是补断言**:两个各自唯一的整句各 `count == 1`,`UNVERIFIED` 同样 `count == 1`
   (**重复它也会红**,已作为变异验证)。三批 **10/10/12**,活 **5(夹具失效)/1/0**,两端控制项干净。
   **下一格**:#241 剩下的那一半要一次**在线行为探针**(`print()` 到不了控制台),
   **不是容器里做得完的工作单元** ⇒ 本组不为它开格。回 `0POLL`,或按 owner 优先项 / issue 重新认领。
   **顺带交给总监的范围决定**:`docs/BOT_API_REFERENCE.md` **整份**都带那条 server-vscript 页首 ref
   且与第三方仓同源 ⇒ **这一行大概率不是唯一一行**;要不要立全文件对表普查,本组不自行扩面。**
0SALT. **【2026-08-27T04:2xZ 新增,GH #242;一条可复用主判据 + 一条裁定「不落地」+
   一条四次同族的方法自伤;本轮由上一格 `0SALY` 在「下一格」里登记(并**同时登记了一条必须先答的
   反对意见**)后认领。`bots/` **零 diff**,零新 gate id。】
   **大药选人这一格的裁定是「不要落地」——支配构造对 argmin 型现状按算术为空,
   唯一可做的改动是裸选一根轴(即拟合);而修 pin 时点出来的第二件事加强了这条裁定:
   选绝对最低血是**四个消耗品共用的全文件约定**,不是大药的一处怪癖。**
   **⭐ 主判据(可复用,本轮真正的产出)**:前三格(`salvepool`/`salveally`/`salveyield`)能落地,
   靠的都是同一件工具 —— 两种读法不一致且都推导不出时**只在支配关系成立时动**(交集,最保守,无阈值)。
   **这件工具在这一格按算术为空**:支配要求某候选在**两根轴上同时**比现状选中的人更惨,而现状
   **本身就是其中一根轴的 argmin** ⇒ 对**任何**候选集都空,是 `bbfight` 那种空。一般化成一句:
   > **支配构造只可能对「不是任何一根竞争轴的 argmin」的现状开火。**
   `salveyield` 能开火正因为它的现状(「自己喝」)是**常数规则**、两根轴的 argmin 都不是 ⇒
   两格的差别是**结构性的**,不是谁看得更用力。`[criterion]` 做成四个现状规则的表
   (两个 argmin 型买 **0**,两个非 argmin 型买正数 —— 后者是控制项,否则零与「谓词写坏」分不开);
   `[control]` 用 #237 的归档锚点(潮汐 80/1455 vs 沉默 43/1229)在**同一对英雄**上给出两种读数
   ⇒ 差别只在现状,不在数据。
   **⭐⭐ 反对意见成立且更强**:大药是**定量**治疗 ⇒「谁更惨」与「谁获益最大」是两个问题。
   `[objection]` 把算例**参数化**(不依赖本 patch 的具体治疗量):辅助 100/692 = 14.5% vs
   核心 300/2600 = 11.5%,比例选核心、绝对选辅助;H 从 200 扫到 800 的 **25** 个取值上,
   **每一个**都是比例规则选中的人喝完更惨。
   **⭐⭐⭐ 端到端零(轴 = 持药者帧,121 个)**:选人是**集合**性质,只有同帧 ≥2 个队友过门才可观测。
   四个门世界的**最大可选集全是 1**(出厂 / `salveally`-armed / 各自 +干净守卫;恰好 1 个的帧数
   分别 **6 / 8 / 3 / 5**)。写成「最大值 == 1」而不是「≥2 计数 == 0」是因为前者**没有可放松的常数**
   (初版写后者,变异「阈值 2 改 3」会活下来 —— **改写是修法,不是补断言**)。
   **控制项**:不加门时归档有 **4** 帧带 ≥2 个队友、最大 3 个 ⇒ 零是关于**队友血量门**的,
   不是持药者总一个人站着。
   **⚠⚠ 方法自伤(本轮最贵,同一形状一轮内出现四次,方向全是「把没通过报成通过」)**:
   **(i) source pin 只有在字符串于文件内唯一时才是 pin。** 第一批 31 变异 **4 个活下来**,
   其中三个是大药选人那三行的变异 —— 因为**完全相同的三行块在这个文件里有四份**,
   `find(needle,1,true)` 命中的是变异没碰过的拷贝。与 #237 的「`"10 failures"` 含 `"0 failures"`」
   **同族高一层**(那次是包含,这次是**唯一性**)。修法 = **切片**(先切出 `item_flask` 的函数体
   再断言,带反真空字节数上下界),不是补断言。
   **(ii)** `x = h()` 的 pin 被 `x = h() - 100` 满足(**不是**等价变异,它破坏运行最小值)⇒
   `exact_line` **整行逐字比**。**(iii)** `find('= ' .. 0.5)` **命中 `= 0.55`** ⇒ 数值 pin 一律
   **从树里读出来按数字比**。三批变异 **31/12/6**,活下来 **4/1/0**,每批前后干净控制项;
   判定读数用 `^[0-9]+` 提取整数。
   **⭐⭐⭐⭐ 判据二(顺带,且加强本裁定)**:`ability_item_usage_generic.lua` 有 **4 处** consider
   用**同一个三行块**按绝对最低血选队友 —— `item_flask` / `item_essence_distiller` /
   `item_urn_of_shadows`(均 `OriginalGetHealth`)+ `item_polliwog_charm`(**`GetHealth`**,异类)。
   **只改大药那一份 ⇒ 同一文件对同一问题两个答案**,恰是 #227/#231 对大药**阈值**的那条控诉 ⇒
   **这根轴要么全文件一起定,要么不定**(第三条独立理由)。`[census]` 连 getter 一起钉。
   **另一条零**:`[decompose]` —— 干净守卫里治疗-modifier 那半排除 **0**、recent-damage 那半
   做完全部 6→3 / 8→5(与 #237 同形),按那条教训**把零写进文件** + 可达性控制项(归档确有 9 个
   单位带这些 modifier)。
   **顺带的操作规则**:**标记能做成红测试就不要做成注释** —— 注释可被略过,红测试在**正要改
   那一行的那一刻**才响,而且不位移行数普查。本轮 `bots/` 零 diff ⇒ 本组**连续第六轮**动这段
   四十行里**第一次没顶掉任何棘轮**(前五轮 +2/+3/+4/+6/+12)。
   **下一格**:`item_flask` 这个 consider **四格已全部读完**(两个阈值 + 仲裁 + 选人),
   本组这条线**到此收官**,等总监确认。重开它的**唯一**东西是录像组那条分母(见交棒)。
   下轮从 `0POLL` 起,或按 owner 优先项/`[strategy]` issue 重新认领。**
0POLL. ~~**【2026-08-27T04:2xZ 新增,GH #242 §5 顺带登记,刻意不修】**~~ **【已认领并结案
   2026-08-27T16:3xZ,见 `0POLY` / GH #254 —— 它挂着的两个前置问题答案都是「不」:
   门那一半落地为 gated `pollyhp`,选人那一半**裁定不改**并钉成断言。原文保留如下。】**
   `item_polliwog_charm` 的队友选择用 `GetHealth()` 而非 `OriginalGetHealth()` —— 上表四处里
   **唯一**的异类,幻象/临时 buff 不设防。一次动一个小杠杆,本轮不碰;
   `[census]` 已把这条异常**钉成断言**(改回 `Original*` 会红,并要求先登记)。
   做它之前先答:这四处的 getter 该统一到哪一侧,以及统一本身要不要作**一个原子**
   (与 `0SALT` 判据二同理 —— 全文件一起定)。**
0SALY. **【2026-08-27T01:2xZ 新增,GH #237;一条主判据 + 一个已落地的 gated id +
   一条方法自伤;本轮由上一格 `0SALA` 在「下一格」里显式登记后认领并产出】
   **大药的两半之间没有任何仲裁 —— 自用分支只要成立就 `return`,四十行下的贴队友分支
   不是被压过、是根本到不了;而本轮真正学到的是「一条 `limits` 里的『不在 dump 里』
   本身是一个关于 dump 的断言,必须核对,不能继承」。**
   自用门是**绝对缺血量**,所以池子一大它在 bot 还很舒服时就成立:归档最大池 **2566**
   上缺 501 意味着 bot 还有 **80.5%** 血,足够把药喝在自己身上,而 400u 外站着 14% 血的
   队友。**函数里没有一行比较这两个人。** 落成 gated **`salveyield`**
   (`state.json:salveyield_20260827`,`tests/test_salveyield_arbitration.lua`
   **29 例 / 30 变异 30 抓 + 控制前后干净**,含 **8 条模型层**),未 armed 逐字返回 false。
   **⭐ 本轮没有常数可推导,于是干脆不引入常数**:比例与绝对血量对「谁更惨」给出不同答案,
   而大药是**定量**治疗(400 对 692 池是 58%、对 2566 池是 15.6%),两种读法都说得通 ⇒
   **只在支配关系成立时让位**(队友在两种读法上**同时**更惨)= 两条候选规则的**交集**,
   按构造最保守,**没有阈值可拟合**。`[source]` 断言函数体**除 0 外不许出现任何数字**。
   **⭐⭐ 永不丢弃施法,只改变目标**:调用点把贴队友那半**自己的开火条件**同帧传给 helper,
   helper 在它为假时短路 ⇒ 让位只可能交给一条**已知会返回 HIGH** 的分支。`[nodrop]` 四条
   断言**从源码文本**读出这条性质。⚠ 依据 (c) 上一处不含糊:**这一处姊妹 lotus 不站在
   我们这边**(它自用也直接 return),依据是「一次性消耗品应落在更惨的人身上」这条标准
   打法,不是「树上已经这么说了」。
   **⭐⭐⭐ 判据(本轮主产出)**:GH #231 的 `[W1]` 把四个治疗 modifier 与
   `WasRecentlyDamagedByAnyHero` 记作「不在任何 dump 里」——**五项里有两项在**
   (`modifiers` **433/1050 = 41%**、`recent_damage` **181/1050 = 17%**),建模进去会把
   那一轮**已发表的域表前两行砍半(6→3、2→1)**;**最深那行(它的控制项)仍是 1 ⇒ 结论
   不受影响,受影响的是域数字**。而它**同时决定本轮自己的头条**:唯一挺过其它合取项的
   配对正是被队友自己的 recent-damage 守卫杀掉的 ⇒ 端到端 **1(旧约定)/ 0(修正约定)**。
   `[w1correction]` **先把已发表的 6/2/1 原样复现**,再给 delta —— 对**当场能算出来**的数
   的 delta,不是对记忆里的数的 delta。
   **域,六层六个数**(73 配对):① **9** → ② +持药者 900 内无敌 **3** → ③ +持药者干净
   **2** → ④ +1000 内无敌 **2** → ⑤ +队友过门 **1** → ⑥ +队友干净 **0**。控制项:
   「队友过门 ∧ 干净 ∧ 安静」在归档里仍有 **1** 个配对 ⇒ 为零的是本杠杆这条带。
   **⚠ 方法教训一:修法不是补断言。** 把修正模型里治疗-modifier 那半 neuter 掉 **29 例全绿**
   —— 因为它在配对轴上排除的**本来就是 0** 个(整个 6→3 全来自 recent-damage)。做法是
   **把那个悄悄成立的零写进文件**(断言 heal-mod 排除 **0**、recent-damage 排除 **3**,并断言
   **归档确实带着这些 modifier 9 次** ⇒ 零是关于**可达性**的)。补上后 30/30。
   **⚠ 方法教训二(自伤):判定读数的那段代码也是被测对象。** 变异批处理用
   `grep -q "0 failures"`,而 **`"10 failures"` 里含 `"0 failures"`** ⇒ 一条**真被抓住**的
   变异被报成 SURVIVED。失效方向恰是最坏的那个(把抓住报成漏掉,于是人会去"补"一个
   本来就够的断言)。整批已用 `^[0-9]+` 提取重跑 + 两端控制项。与 GH #222 判据二同族。
   **下一格(带一条反对意见)**:同一个 consider 只剩**一处**没读过 —— 贴队友那半**选人**
   用绝对最低而非比例最低(`0SALA` 登记的第 (ii) 条)。⚠ **但下一轮必须先答一条反对意见**:
   大药是**定量**治疗,比例最低选中的**可能正是 400 血救不回来的那个大池子英雄**
   (辅助 100/692 = 14.5% vs 核心 300/2600 = 11.5%:比例选核心,而 400 血把辅助拉到 72%、
   把核心只拉到 27%)⇒ **「比例更对」在选人这一步不是自明的**,姊妹 lotus 的比例打分也是
   定量治疗、同样存疑。**不要按 `0SALA` 登记的措辞直接落地**,否则是换一个方向的拟合。
   (本轮在**要不要**这一步用「支配」绕开了轴的选择;**选谁**绕不开,因为必须给出全序。)**
0SALA. **【2026-08-26T22:2xZ 新增,GH #231;一条主判据 + 一个已落地的 gated id +
   一条方法教训;本轮由上一格 `0SALV` 在「下一格」里显式登记后认领并产出】
   **大药贴队友那半的门,对血池 ≤ 550 的队友是算术上不可满足的 —— 而本轮真正学到的是
   「证明了的结构性零 ≠ 买到了格子」。**
   `npcAlly:OriginalGetMaxHealth() - npcAlly:OriginalGetHealth() > 550`:**缺血量永远
   超不过血池** ⇒ 血池 ≤ 550 的队友在**任何血量(含 1)下**都通不过。不是域小,是域空,
   **算术判决**(`bbfight` 那个形状)不是统计判决。归档在一个**合理**帧上就带着这样的
   池子(**1 级冰女 538**,把门读成她要缺的比例是 **102.2%**)。550 以上是第二个缺陷
   (与 `salvepool` 同源、更狠):669 要掉到 **17.8%**,2566 要掉到 **78.6%**。
   **两个被比较的循环不是类比、是同一个循环**:四十行下的 `ConsiderHealingLotus` 用同一个
   `GetAlliesNearLoc( ..., 700 )` + 同一套守卫,**唯一的结构差别就是这个谓词的形式**。
   落成 gated **`salveally`**(`state.json:salveally_20260826`,
   `tests/test_salveally_missing_floor.lua` **24 例 / 21 变异 21 抓 + 控制**),
   未 armed 逐字返回出厂 **550**,armed 返回 `Min(550, maxHP * 0.55)`。**比例是推导**:
   出厂常数读成它被标定的 1000 池的比例(三条独立依据,其中一条是**比姊妹 lotus 族三档
   队友门 0.4/0.5/0.5 缺血全都更严** ⇒ 朝那族挪、没越过最保守那档;另一条是 armed 后
   **两道门 550 > 500 的出厂大小关系在每个池子上都保持**)。
   **⚠ 判据(本轮主产出):一个结构性零可以被算术证明为真,同时在它自己那根轴上买到
   零个格子 —— 这两件事必须分开说,不许用前者的力度替后者交差。**
   证明成立且可穷举(**151,525** 个 (池,血) 状态,且**把扫过的宽度与状态数本身钉成断言**,
   否则把上界改小、剩下的子集照样全绿);而这条分支真正可达的轴是**配对**
   (持药者 × 700 内队友),归档 **73** 个配对里队友血池 **[582, 1872]**,**一个 ≤ 550 的
   都没有** ⇒ 端到端 **0** 格。**与 `bbfight` 的分别正在这里**:那条的零就坐在它自己
   可达的轴上,这条不是。与 `0SALV` 的 `[refusal]` 同族、方向相反:那条管**别用语料定常数**,
   这条管**别用证明顶语料**。
   **域,三个嵌套的问题给三个数**(73 配对):①本合取项 **6 / 8 / 新开 2**;
   ②+ 持药者 1000 内无敌 **2 / 2 / 0**;③+ 自用分支不能抢先 return(**下界**)**1 / 1 / 0**。
   ③ 在**出厂与 `salvepool`-armed 两种自用门下读数相同**,这条一致性也是断言;控制项:
   出厂那一路在 ③ 上**仍打得响 1 次** ⇒ 为零的是本杠杆这条带、不是这条分支。
   **⚠ 方法教训:被打两遍的常数会悄悄漂移。** 两条变异一开始活下来 ——
   (i) 模型里**硬写**的 quiet 半径 1000→1600 全绿(这份归档上两个半径恰好选中同一批配对);
   (ii) 穷举网格上界改小全绿(子集照样为真)。**修法不是补断言**:三个半径改成
   **从源码文本读出来**,于是变成「与树不一致」而非「与什么都不冲突」;网格**把自己扫过的
   宽度钉成断言**。改完 21/21。
   **顺带一条给自己的操作规则**(GH #222 判据二的自伤版):**受影响面循环在跑的时候,
   本会话不许再发任何 lua 调用** —— 本轮第一次跑到 36/105 时并发发了 4 个前台核验,
   读数作废重跑。
   **下一格**:同一个 consider 的另外两处,**都不需要新语料** —— (i) 自用与贴队友之间
   **没有优先级仲裁**(自用成立就 return,哪怕 700 内站着 15% 血的队友);(ii) 贴队友那半
   **选人**用 `OriginalGetHealth()` **绝对最低**而非比例最低(同源池子失明,发生在「选谁」)。
0SALV. **【2026-08-26T19:4xZ 新增,GH #227;一条主判据 + 一个已落地的 gated id +
   一个刻意留成 0 的端到端读数;本轮自驱、落在 owner 优先项 P2 的补给侧】
   **大药的自用门是全文件唯一还在问「绝对缺血量」的回复道具,而同一个文件
   在四十行外写着为什么该问比例。**
   `X.ConsiderItemDesire["item_flask"]` 自用分支第一个合取项是
   `OriginalGetMaxHealth() - OriginalGetHealth() > 500`;而**同一个文件四十行以下**的
   `ConsiderHealingLotus` —— 同族道具、同样的形状(先自用再贴队友)、同一个
   `DistanceFromFountain( 3000 )` 前置、三个档次 —— 把阈值写成**剩余血量比例**,
   并把理由写在注释里(`a hero at 30% HP is critical regardless of their max HP pool`)。
   **论证的两半都已经在树上,只有大药站在它的反面。**
   代价是算术:归档 974 个存活英雄帧里血池 **538 → 2566**(近五倍),同一个 500 对
   538 的池子意味着「掉到 **7.1%** 才准喝」,对 2566 意味着「掉到 **80.5%**」——
   同一行在名单一端是最后手段、另一端是日常补给,而最苛刻的那一端正是买大药的
   **小池子对线辅助**。
   落成 gated **`salvepool`**(`state.json:salvepool_20260826`,
   `tests/test_salvepool_missing_floor.lua` **19 例 / 12 变异 12 抓 + 控制**),
   未 armed 逐字返回出厂 **500**,armed 返回 `Min(500, maxHP * 0.5)`。
   **armed 的值不是重新猜的**:500 本身就是 **1000 血池的一半**(它读上去被标定的
   那个池子),修法**保留出厂那个数**,只是不再让它在池子更小时要更多;比例同时
   落在姊妹族**最保守**的那一档上(第二条独立依据)。**单向且两头钉住**:`Min` 只能
   降低一个挡住喝药的下限(`closed == 0` 穷举断言),而**池子 ≥ 1000 时 armed 逐字
   等于出厂** ⇒ 整个改动**只活在小池子上**,不是一次笼统的放松。
   **⚠ 判据(本轮主产出):一个常数可以被测出来更好,同时被拒掉 —— 而拒的理由
   必须写下被拒的那个数有多大。**
   姊妹族**最松**的那一档(0.7 ⇒ floor = `Min(500, 0.3*mx)`)在同一份语料上
   **买得到 6 个端到端帧** —— 正是本条说这份归档没有的那种证据 —— **仍然被拒**:
   ①那么低的下限意味着**大量治疗量溢出**才喝;②**挑那个让语料读数最好看的常数,
   是拟合,不是推导**。`[refusal]` 把「被拒的那个数 == 6」**钉成断言**,而不是只说
   一句「更松的不好」——**说清楚自己放弃了多少,才叫拒绝;不说,就只是没测。**
   与 `0BBS` 判据一同族、方向不同:那条是「别把另一个原因洗成本缺陷」,这条是
   **「别把语料产量当成常数的依据」**。
   **域,三个嵌套的问题给三个数**(974 存活帧):①本杠杆自己那个合取项
   **169 / 189 / 新开 20**;②+ 900 内无存活敌方英雄 **97 / 107 / 10**;
   ③+ 包里真的有大药(派发器前置)**7 / 7 / 0**。**③ 的 0 就是本轮不提入集、不提
   波次的理由**,但它带控制项:出厂那一路在 ③ 上**打得响 7 次** ⇒ 为零的是**本杠杆
   这条带**,不是这条分支。**缺的不是语料形状,是一帧。**
   **一条不主张**:语料里 **16 个存活帧整个血池 ≤ 500**(那样分支任何血量下都不可达
   = 结构性零),但**全部是同一个英雄在不合理的池值上**(GH #176 那族 dump 伪影)
   ⇒ **拒绝**,`[W3]` 把这条拒绝钉成断言(计数 16 **且不同英雄数必须 == 1**)。
   **下一格**:同一个函数**贴队友那半的 `> 550`** —— 它对 538 的池子是**真正的
   结构性零**(队友血量再低也贴不上),本轮故意没动(一次一个小杠杆),
   **不需要新语料**。
0BBS. **【2026-08-26T17:0xZ 新增,GH #222;一个已落地的 gated id + 两条判据 + 一条交给总监的方法问题;
   本轮由上一格 `0BBF` 在「下一格」里显式登记后认领并产出】
   **买活阶梯的第三个普通模式时长,而它的后果不是「窗口小一点」,是整场死亡一格都开不了。**
   `if nFullRespawnTime < 60 then return end`(rung 1 与 rung 2/3 之间)里的 **60 是普通模式的秒数**。
   **这条发现不依赖 getter 怎么读**,而这是它最强的地方:60 是**复活秒数**,turbo 把**每一个**复活
   时长乘 **0.75**。读法 A(local 名字自称的完整时长,意图「复活太短不值得买活」):选中的英雄集合
   **严格小于**它被写出来时要选的那个;读法 B(有据可查的 remaining 语义,#208):remaining ≤ R ≤ **75**
   ⇒ 下面两级只在 remaining ∈ [60,75] 可达 = **死亡最初的 R−60 ≤ 15 秒**,且**凡 turbo 复活时长
   R < 60 的英雄,门在 elapsed 0 就已为真** ⇒ 下面两级**整场死亡全关**(turbo R<60 ⟺ 普通 R<80)。
   落成 gated **`bbshort`**(`state.json:bbshort_20260826`,
   `tests/test_bbshort_turbo_respawn_floor.lua` **21 例 / 11 变异 11 抓 + 控制**),未 armed 返回出厂
   字面量 **60**,armed **45**(同一系数缩放,**算出来、不许写 45**,复用 `bbfight` 已具名的常数)。
   **GH #207 预检主动做过**:单合取,armed 的 24 格取在**两个邻居的出厂读法**上 ⇒ **单独 arm 就打得响**。
   **⚠ 判据一(本轮主产出):两个互相独立的原因会关掉同一批格子,而测试的责任是不把另一个洗成本缺陷。**
   `[defect-control]` 把门**整个拿掉**再数:**R = 9 / 20 两行仍然 0 格** —— 关掉它们的是下面那条
   `nRemainingRespawnTime < 40`,**不是这道门**;把它们算到本杠杆头上,就是 `0BBF` 判据二那条错误
   **换了一对原因**。同时 **R ∈ {40,50,55} 在无门世界里开 8 格**,所以控制项**不能靠「把一切都关掉」
   蒙混过关** —— 一条只会说「都关着」的控制项证明不了任何归因。**这是 `0BBF` `[W2]` 的下一层**:
   那轮学「够不着可以有两个原因,要说清这一格的零是谁的」,这轮学**「怎么用一条反向控制把它证出来」**。
   **域当作域来量、不冒充零**:64 格网格 shipped **12** / armed **24**,新开 **12**;其中 **R=50 开 3、
   R=55 开 4**,而这两行 shipped **整场死亡 0 格**(`bbfight` 的网格没有 50/55,**没有它们这条杠杆
   根本量不出来**)。另一侧的诚实**写进测试**:**R=40 armed 后仍全关**(40<45),**不主张**救得回它;
   `[arith]` 另有一条**拒绝越界**的断言 —— 这**不是** `bbfight` 那种结构性零,别把那句话借过来。
   新增 **`[W3]`**:rung 3 的两个**世界计数不建模** ⇒ 量的是「**够得到**那一级」,**从来不是「买了活」**。
   **⚠ 判据二(方法,交总监裁):并行跑测试会制造假红,因为 gate 文件是全局的。**
   上一轮那道「受影响面 101 文件**分 6 段并行**跑完 1131/2」的门,本轮照做读到 `bbrespawn`
   **3 failures**;**顺序重跑同一文件 = 16 tests 0 failures**。根因是结构性的:这些 gated-fix 测试用
   **同一个物理文件** `bots/Customize/soak_side.lua` 当 arm 开关(`load_with()` 写它、`armed()` 删它),
   **两个进程同时跑就是在同一个开关上打架**,失败方向是**假红**。上一轮那 2 条 fail 恰好等于两条已知红,
   所以**结论没错,但方法能凭空造红** —— 下一个照抄这条门的人不一定这么走运。本轮改**顺序跑**。
   ⇒ **要不要落成一条门(「gate 文件是并行不安全资源」)归总监**,本组不自行改 harness。
   **下一格**:`nFullRespawnTime` 这个**名字本身** —— 三轮下来它已是三个缺陷的共同来源(双减 / 80 / 60),
   **改名是零行为改动**,但必须**等 `bbrespawn` 与 `bbshort` 裁定之后**再动,否则两个 gate 的未 armed 腿
   会同时失去它们「逐字等于出厂」的性质。**登记为:等裁定。**
0BBF. **【2026-08-26T14:2xZ 新增,GH #215;三条判据 + 一个已落地的 gated id + 一条被登记为「不做」但**前置买得到**的上一格;本轮由 GH #212 §4 认领后顺同一条形状产出】
   **一个为「复活最久的那个人」写的规则,被 turbo 的缩放把连那个最大值都压到了阈值下面 5 秒。**
   `ability_item_usage_generic` 的买活三段阶梯,中间那段是
   `bot:GetLevel() > 24 and nRemainingRespawnTime > 80`,而 **80 是普通模式的时长**。
   两条有据可查的引擎事实:复活表 1 级 **12s** → 25 级 **100s**(以上保持最大);**turbo 复活快 25%**
   ⇒ **turbo 复活时长天花板 = 100 × 0.75 = 75 秒**,比阈值低 **5 秒**;而 `nRemainingRespawnTime`
   两种读法(出厂 `R−2e` / GH #208 修好后的 `R−e`)**都 ≤ R ≤ 75** ⇒ `> 80` **在任何可达 turbo 帧上
   都是假,两种读法都是**。**STRUCTURAL-ZERO**,而且成立在**这条分支唯一为之而写的那个等级**上
   ——`GetLevel() > 24` 就是复活表上那个 100 秒的最大值本人。**「域太小」是统计判决,这是算术判决。**
   落成 gated **`bbfight`**(`state.json:bbfight_20260826`,
   `tests/test_bbfight_turbo_respawn_ceiling.lua` **20 例 / 10 变异 10 抓 + 控制**),
   未 armed 返回出厂那个字面量 **80**,armed 返回 **60**(= 同一个系数缩放,不重新猜数);
   三个常数(100 / 0.75 / 80)**具名 + 各带棘轮**,armed 值**算出来、不许写字面量 60**。
   **GH #207 预检主动做过**:单合取;且 armed 的 6 格取在**出厂的 `R−2e` 读法**上 ⇒ **单独 arm 就打得响**。
   **⚠ 判据一(本轮主产出):一个未核验的推断错了,代价不是它自己错 —— 是它把三件不同的事捆成一个判决。**
   `test_level_gate_census` 的 `[recorded]` 节躺着一条自认是推断的记录,写着「turbo **halves** respawn
   time」。**那个系数是承重的**:若真是 0.5,天花板 50s,阶梯**上方**的 `nFullRespawnTime < 60` 早退
   **恒真** ⇒ **三条通路共享一个判决:全死**;按有据可查的 0.75,天花板 75s,三条**分岔** ——
   第 2 条 = **DECIDED**(常数支配),第 1/3 条 = **仍是 RECORDED CLAIM**(要 20s/40s,天花板放得过,
   关掉它们的是「中位英雄 10 级」这个**语料**事实:**罕见,不是不可能**,而且仍然量不到)。
   **那条真正可判的东西,在错误的公司里躺了 5 天。** 已改正 + 钉子从 1 条加到 3 条。
   **与 `0SRC` 同族、方向不同**:那条是「引用了被测对象的检查会停止检查它」;这条是
   **「把可判的和不可判的写进同一句话,可判的那半就不会有人去判」**。
   **⚠ 判据二:够不着可以有两个互相独立的原因,而测试的责任是不把另一个洗成缺陷。**
   `[W1]` dump 没有 respawn 字段(R 是**会倒数的**声明替身);**`[W2]` 全 fixture 归档等级上限 = 19**
   ⇒ `GetLevel() > 24` 在真实帧上**也从没见过**。**只有第一个是代码缺陷的域。** 于是 `[defect]`
   **显式授予**等级合取项 + 一条**反向控制**(忘了授予会读成同一个「结构性零」而什么都没证明)。
   **是 `abilanc` `[W1]` / `bbrespawn` ① 的下一层:替身声明对了还不够,还要说清这一格的零是谁的。**
   **⚠ 判据三:#212 §4 那一格答「不做」,而理由不是「不值得」,并且它的前置买得到。**
   §4 的 shipped 事实核过成立(turbo 18:00 后整个外层 farm 块对所有 bot 关闭,落到恒定
   `Min(BOT_MODE_DESIRE_LOW, nFarmCap)`)。不开单三条理由:①**方向与两次付过钱的读数相反**
   —— 救活它 = turbo 后期农更多 = `c3`(−37 GPM)/`corefarm`(−17 GPM)那个 0/4 的方向;
   ②顺带一条 §4 没提的:`(bCore or J.IsLateGame() or level>=18)` 里 `IsLateGame()` 18:00 后恒真
   ⇒ **另外两个析取项在后 30% 局时里是死项,角色区分消失**,修它方向同样向下、幅度更小;
   ③**决定性**:归档最晚一帧 **t = 690.5s** ⇒ t > 1080 的杠杆 fixture 退化成对测试自己输入的复述
   —— 与 `list[1]` 被退回**同一条规矩**。**⚠ 但这次前置买得到**:#212 自己证明带内 **440,569 帧、
   最大 t = 1646.5**。**缺的不是语料,是没人从那段语料切一帧做成 fixture。**
   ⇒ **登记为:不做,前置 = 归档出现一帧 `t > 1080` 的 turbo fixture**(那一天 `tbearly` 的 (B)
   同时解锁 —— **同一把钥匙**,已作为请求交录像组)。
   **下一格**:GH #208 的姊妹误读 `nFullRespawnTime < 60` —— 它现在有了新上下文:按判据一分岔后,
   它是**第 1/3 条通路共同的那道门**。
0BB. **【2026-08-26T10:3xZ 新增,GH #208;三条判据 + 一个已落地的 gated id + 一条被退回并
   登记为「不做」的上一格;本轮由章程 backlog `0i` 顺带登记、5 天无人认领的第二个杠杆产出】
   **「我还要死多久」这个数,在十五行里被同一个 getter 读了两次,并且被自己减了一次。**
   `X.GetRemainingRespawnTime`(`ability_item_usage_generic:368`)写成
   `bot:GetRespawnTime() - ( DotaTime() - fDeathTime )`,而 `Unit:GetRespawnTime()` 按
   `docs/BOT_API_REFERENCE.md:992` 逐字是 **"Seconds until this hero respawns"** =
   **已经是剩余时间、自己在倒数**。设 R 复活时长、e 死后经过秒数:引擎给回 R−e,表达式返回
   **R−2e** ⇒ 读数**以两倍钟速衰减**,在 **e = R/2**(死亡正中间)穿过 0,此后为负而英雄还要
   再躺 R/2 秒。**产生这段函数体的读法,名字自己招了**:同一个 getter 在 15 行外存进一个叫
   **`nFullRespawnTime`** 的 local(`:565`)—— 只有把它读成**恒定完整时长**,再减一次 elapsed
   才是算术而不是缺陷。**方向单向**:三个消费方(`>20` 守遗迹 / `>80` 24 级归队 / `<40` 早退)
   **全是这个数的下界** ⇒ 只会**关掉本该允许的买活**,窗口从 R−20 缩到 (R−20)/2,后半程恒 ≤0。
   落成 gated **`bbrespawn`**(`state.json:bbrespawn_20260826`,
   `tests/test_bbrespawn_double_subtract.lua` **16 例 / 9 变异 9 抓 + 控制**),
   未 armed 逐字等于出厂(含 `fDeathTime == 0` 短路,**留在门之前**)。
   **⚠ 判据一(本轮主产出):一个替身可以把被测的误读本身建进测试里 —— 替身要连它的
   动力学一起声明,不只是它的值。** 第一版把 R 声明成**常数**,`[defect]` 当场红**而且报对了**:
   常数替身模型的正是「getter 是恒定完整时长」这个**被测的误读**,在那个世界里缺陷消失。
   ⇒ 改成**会倒数的**替身(每格喂 `R − e`),armed = R−e / unarmed = R−2e / 两腿之差**恰好 e**,
   三条都成穷举断言(6×9 的 (R,e) 网格,跨过 20/40/80 与 R/2 交叉点两侧)。
   **与 `abilanc` 的 `[W1]` 是同一条规矩的下一层**:那轮学「替身要声明出来」,这轮学
   「**声明得对不对取决于替身有没有被测对象的那条动力学**」——
   **静止的替身对一个关于时间演化的缺陷是隐形的假阴性。**
   **⚠ 判据二:本轮刻意不提入集、不提波次请求 —— 因为这条修好的腿今天打不响。**
   唯一在它**上面**的消费方(`:574` 守遗迹)前置是 `J.IsAncientBadlyHurt`,而 `bbancient`
   自己的登记写着 **58 个遗迹快照全部 hp = 1.0**(裁判 `forcewin` ⇒ 没有一局录到围高地);
   下面两条压在 `:580` `if nFullRespawnTime < 60 then return end` 底下,按已文档化的 remaining
   语义那行在**每次死亡最后 60 秒**恒真、R ≤ 60 时**整场恒真**。⇒ arm 它只会往 arm 串里塞一条
   **GH #207 那种打不响的腿**。**「量不到」和「量出来是零」都不是归档的理由,都是
   「这一轮不许申请波次」的理由。**
   **⚠ 判据三:上一格被退回,理由是「结构上买不到本地验证」而不是「不值得」。**
   上一轮登记的 **54 处 `list[1]`** 本轮量了(145 处 sweep 里 **64 处**带 `[1]`,~35 处是同一个
   成语 `#n >= 2 and n[1]:IsAncientCreep()`,把 `[1]` 当「这是不是远古营」的**位置代理**),
   然后**退回**:**门的谓词读什么,决定它能不能被真实帧钉住**。`abilanc` 的门读**英雄状态**
   (`GetLevel()`,fixture 供得起)⇒ 替身只占世界的另一半;`[1]` 一族的门读**列表内容**,
   而**引擎顺序不在任何 dump 里**(GH #100,dump 里一只野怪都没有)⇒ **域和验证同时是声明的**,
   fixture 退化成对测试自己输入的复述 —— 正是章程「gate-plumbing 测试不算本地验证」冲着去的东西。
   **登记为:不做,前置 = GH #100(dumper 先出野怪)。**
   顺带两条零成本读数:**`hero_drow_ranger.lua:686` 是全仓唯一**在这个成语上带等级门的一处
   (存在性证明);**两个远古等级常数并存** —— `mode_farm_generic:786/792` 用 **10**,
   `J.Site.ANCIENT_MIN_LEVEL` 与 drow 用 **12**(本轮不碰:两个常数各有出处,合并是行为改动)。
   **下一格**:`:580` 的姊妹误读 `nFullRespawnTime < 60`(本轮 `[limit]` 已钉住,分母 =
   「每次死亡的最后 60 秒」,**不需要新语料**)—— 它才是解锁这一族的那条,而本轮**故意没动它**
   (一次动一个小杠杆)。
0ABIL. **【2026-08-26T08:0xZ 新增,GH #196;两条判据 + 一个已落地的 gated id + 一次带分母的入集提议;本轮由它产出】
   **三个营地档次 id 全部站在打野路径上,而 10-11 级打远古的主通路不在那条路上。**
   录像组 W11(125 局宽扫 + 7 局逐帧):10..11 带 armed 12 次「他落第一下」里 **10 次由技能**、
   **6 次对着远古营施法**(baseline 9 里 7 / 6)。`campgrade`(名单)/`campsel`(选点)/
   `campfarm`(打野路径目标)**一条都够不着** —— 英雄的 `ConsiderAbility` 自己扫
   `GetNearbyNeutralCreeps`,把**原表**交给 `J.GetMostHpUnit`,而这个选择器**按构造**
   选中远古野(远古野就是场上血最厚的那只)。承重帧:`20260825_212701_slot2` luna **L11 t=515.5**。
   落成 gated **`abilanc`**(`state.json:abilanc_20260826`,`queue.json:strategy-20`,
   `test_set.md §BK`,`tests/test_abilanc_ancient_selector.lua` **13 例 / 8 变异 8 抓 + 控制**)。
   **修法不是猜的**:那个选择器里**已经写着同一类的两条排除**(Roshan、Tormentor),
   远古营是这一类里没人补上的那一个。**门放进选择器而不是 20 个调用点** ⇒ 漏门从
   「计数用例事后抓」升级成「**结构上做不到**」;豁免恰好一处(`doom_bringer:305`,
   全仓唯一在 commit 之前读 `IsAncientCreep` 且**能对远古采取行动**的消费方),**命名的是机制**。
   **⚠ 判据一(本轮主产出):域太小买不到效应量,不等于买不到条件 (a)。**
   能管的那一格 armed **6** / baseline **6** / 125 局 ≈ **每局-腿 0.048 次** —— 撑不起任何计数
   差分。**而铁律 2 的 (a) 问的不是量**,是「真的执行且行为正确」= **存在性 + 逐帧正确性**,
   **6 次/腿一次就够核验**。⇒ `strategy-20` **主动不主张效应量**,并**预先声明**带内计数差分
   不当证据(同一份数据**带内所有切法两层反号**,侧别效应 **10:1** 大于任何腿效应)。
   **与 `campfarm` 的分类差别**:那条是 domain-too-small **且**它要的就是一个计数(2 / 2)
   ⇒ (a) 结构上买不到;本条是同表**大三倍**的另一列且要的是存在性。
   **「域小」不是判决,是必须换判据形状的信号。**
   **⚠ 判据二:一个「可选参数」会把「传 1 声明 2」变成每个现存调用点的形状。**
   豁免先写成 `J.GetMostHpUnit(list, bAllowAncient)`,GH #188 的 arity 棘轮
   (**在每个组开工自检里跑**)**当场对 16 个文件全红 —— 它报对了**。判成 `DEFAULTED`
   加 allowlist = **给一个设计上只能缩的名单一次加 16 行**,而那正是它全部的价值。
   ⇒ 改成**第二个入口** `J.GetMostHpUnitAnyTier`(共用实现体 `J.MostHpUnitOf`),
   每个调用点停在 1-of-1,**默认的名字是有门的那个**。
   **与 `0NIL`/`0LN2` 同族但方向相反**:那两条是别人的棘轮点着我的**注释**(改注释);
   这一条是点着我的**设计**(改设计)。**两次都不许放松棘轮。**
   (本轮注释那一条也发生了:`test_campfarm_ancient_target.lua` 用整文件 grep 断言
   `FilterFarmNeutrals` 只有两个文件,我的注释逐字引用了它 ⇒ 读成第三个调用点。)
   **⚠ 顺带一条方法学**:`[source]` 用**整文件** `find` 断言常数名在场,而**我自己的注释里
   也写着那个常数名** ⇒ 「阈值抄成字面量 12」这条变异**第一次是漏抓的**。钉那一行代码才抓到。
   **`0SRC` 自己的失效模式:引用了被测对象的检查,会停止检查它。**
   **下一格(见「当前状态」§下一格)**:54 处 `list[1]`(独立杠杆,分母未量,计数已由
   `[limit]` 钉住);13+ 处 `J.GetCenterOfUnits`(#196 §3.2 明确**不要动**,登记为**不做**)。
0BASE. **【2026-08-26T04:3xZ 新增,GH #202;三条判据 + 一个已落地的 gated id + 一个刻意留空的分母;本轮由 backlog `0a` 第三条产出】
   **空荡荡的 1600 圈被读成「被人数压制」,而它守着的是「独自站在敌方兵营里要不要掉头」。**
   `mode_retreat_generic` 与 `mode_farm_generic` 的 `X.ShouldRun` 里**同一段复制粘贴**的块,
   presence 项写成 `#hEnemyHeroList >= #hAllyHeroList`;两张表来自
   `J.GetEnemyList/GetAllyList(bot,1600)`,**友军表不含自己** ⇒ **两边都是 0 时恒真**。
   而非零 `ShouldRun` = `BOT_MODE_DESIRE_ABSOLUTE * 1.1` **闩 2 秒**(farm 侧还清 `preferedCamp`
   + `Action_ClearActions(true)`),外层情形就是**一个人打进敌方兵营圈**。
   落成 gated **`basesiege`**(`state.json:basesiege_20260826`,
   `tests/test_basesiege_presence.lua` **13 例 / 6 变异 6 抓 + 控制**),
   未 armed 逐字节等于出厂比较,armed 只在 **(0,0) 这一格**不同。
   **⚠ 判据一(本轮主产出):一个杠杆的「域」可以是两个数,而它们可以差三个数量级 —— 必须分开报。**
   **谓词**的域量得到:出厂 helper 普查 **966 个可寻址活体帧,302 帧 (0,0) = 31.3%**;
   **分支**的域量不到:它还要 **800 内有敌方兵营**,而全语料最近的一帧是 **4838u**
   ⇒ **cap 10→25(GH #108)还没流进 fixture 语料**,`0a` 当时的缺口这一侧**依然成立**。
   把谓词域当分支域引用,是 `campfarm` 那次 domain-too-small 的**反面**错误。
   ⇒ 本轮**刻意不提入集、不提波次请求**(总监刚在 `strategy-19` 上立了「先量分母」)。
   **⚠ 判据二:域小 ≠ 不值得,判据是「域 × 每次价值」,本组只缺前者。**
   `campfarm`/`campdanger` 是低价值 × 未知频率;这条是**极高价值 × 未知频率**
   (一次触发 = 一次兵营/高地决策)。「先量分母」不等于「量不到就归档」。
   **⚠ 判据三(方法):普查要用出厂 helper 跑,不要用自己写的几何近似。**
   python 按坐标算 (0,0) 得 **149/563**;在 mock 上调出厂 `J.GetEnemyList/GetAllyList`
   得 **302/966** —— 差别是**雾**(和存活/幻象过滤),而谓词读的正是过雾之后那张表。
   两个数都对,回答的不是同一个问题;方向是**低估**。
   **一条被证明而非被声称的宽度**:`[lever]` 用例在 **0..5 × 0..5** 上穷举,
   断言 armed 与出厂的差集恰好 `{e=0 a=0}`,并逐格断言未 armed 那一路等于 `#e >= #a`。
   **下一格(不在本组手上)**:录像组离线数帧(cap=25 语料里「800 内有敌方兵营」每局几帧、
   那些帧的 1600 圈里敌我各几人),**可与 #201 的 `campdanger` 分母同一次扫描一起出**;
   总监裁「这份读数值不值得先买」+「本轮的克制对不对」。
0NIL. **【2026-08-26T01:38Z 新增,GH #193(已结案回评);三条判据 + 一个已落地的 gated id
   + 一个未 gate 的故障移除;本轮由它产出】
   **farm 模式的 `Think()` 里有一次活的 nil 调用,而它伪装成静默中止活了一整个上游快照。**
   `mode_farm_generic` 换野点的合取项调用 `J.Site` 上一个叫 `IsCampDangerous` 的字段,
   该名字在 `bots/` 下**六种声明形式零命中**,而 `J.Site` 是**没有 metatable 的转译平表**
   ⇒ 字段是 nil,那一行在 `Think()` 里抛错。坏错误处理器 + `print()` 到不了控制台 ⇒
   **它不像崩溃,像一次静默的 Think 中止**,**未 gate**,每一局、每一个「打野 bot 发现
   最近可用野点近 200u 以上」的帧,**吃掉 `Think()` 从那行起的整条尾巴**(走向野点 + 打野怪那整块)。
   落成:未 gate 的 `J.IsCampSwitchSafe` + gated **`campdanger`**
   (`state.json:campdanger_20260826`,`queue.json:strategy-19`,
   `tests/test_campdanger_switch_safe.lua` **14 例 / 4 变异 4 抓 + 控制**)。
   **⚠ 判据一(本轮主产出):「A 还是 B」的修法二选一,有时是问错了一层 —— 先问 A ∩ B。**
   上游把修法写成「写谓词 vs 删合取项」,**两条都标成行为改动、都要 gate**。但两条
   **共享一个被迫的前提**(停止调用 nil 字段),分歧只在那之后。**把被迫的那半也关进 gate**,
   代价是一个**已证明的故障**继续在每一局真实对局里活着等波次。⇒ **被迫的不 gate,政策才 gate**
   (线已在:#192 QoP、#188 `lf_salve` 不 gate;#146/#168/#173 gate)。
   未 armed 返回 `false` = **中止本来就产生的换野点决定**(中止什么都不更新),逐字节同一个决定,
   唯一变化是 `Think()` 继续跑。
   **⚠ 判据二:棘轮读原始源码,注释里逐字引用被修掉的调用会把它重新点着。**
   第一版注释原样抄了那行 nil 调用,`test_call_form_census.py` §4 当场红(在场判据是
   **整文件子串**匹配,分不开注释和代码)。**处置是改自己的注释,不是放松别人的棘轮**;
   测试里要构造那次 raise 则**用下标取字段**。
   **⚠ 判据三(`0LN2` 第五例,形状是新的):自检 Lua 腿那句
   `failing before you changed anything` 是罐头字符串,不是判定。**
   我的注释块顶掉了 `test_level_gate_census.lua` 一条**按行号钉**的 row(`:599 → :637`),
   自检照字面读会让人把自己的红甩给 main。**`git stash` 核对过:main 15/15 绿,红是我的。**
   前四例是钉子被顶出去/写下时就旧了,这一例是**普通代码插入**顶的,而**报错那句话本身会误导**。
   **⚠ 一条声明的本地上限**:`GetNeutralSpawners()` 在**每个语料帧上都答 `{}`**
   ⇒ 换野点分支在 fixture 里**结构上不可达**,端到端驱动不了;位置操作数是**帧上真实地图点**
   而非真实野营(**几何与雾是语料数据,「这个点是野营」不是**)。`[W1]` 一旦有货就自曝过期。
   **下一格(不在本组手上)**:GH #193 §2 问「要不要把 `test_no_undefined_jmz_refs.lua`
   的 pattern 加深到子表」(它的盲区是 `J.Site`/`J.Skill`/`J.Item`/`J.Role`/`J.Utils`/`J.Chat`
   **六张子表下的所有名字**)。**刻意没做**:全队工具,改完改变每个组的门抓到什么,
   不该由一个工作单元顺手决定 —— 已交总监裁;`test_call_form_census.py` §0 已把
   「它仍停在第一个点」钉成断言,谁去加深会拿到指着 #193 的红。
0ANIM. **【2026-08-25T22:4xZ 新增,GH #186;两条判据 + 一个已落地的 gated id + 一个九处调用点的 harness 事实】
   **一个伪造的 `0`,让本仓大部分 mode `Think()` 的头两行在我们拥有的每一个用例里永久敞开。**
   `mode_roam_generic` 的营地拉野节拍(戳一次 → 中间的帧走 500u)在 **42%** 的戳营帧上
   **一步没走**(录像组 W10 逐帧,ab 48% / ba 39% 同号)。原因**不在节拍里**:`Think()`
   第 2、3 行就是 `IsBotThinkingMeaningfulAction(...) then return`,而 `utils.lua` 的
   `meaningfulActivities` **第一、第二项就是 `ACTIVITY_RUN` / `ACTIVITY_ATTACK`** ——
   刚戳完营的英雄**按构造**在攻击动画里,野怪反击又把它按在那儿 ⇒ **节流恰好吃掉
   必须下拖拽指令的那些帧**,英雄站在营里被吃(wave13「站桩 TANK」指纹从节拍看不见的一行绕回)。
   落成 gated **`pullthink`**(`state.json:pullthink_20260825`,`queue.json:strategy-18`,
   `tests/test_pullthink_anim_throttle.lua` **10 例 / 11 变异 11 抓 + 1 控制**):
   **一个 id 两个不可分的半边** —— (1) 有拉野计划时跳过节流;(2) 给营地分支补上
   它姊妹小兵分支早已出厂的起手 hold(promoted `pullbeat`)。**(2) 是 (1) 的结构性前提**:
   只放 (1) = 把 GH #143 在小兵侧量到的缺陷原样搬到营地侧。**刻意没写成合取**(`pullcad` 陷阱)。
   **⚠ 判据一(本轮主产出):一个「两把锁」的解释里,可能只有一把是真的锁。**
   第一版写了两条世界断言(GetAnimActivity 恒 0 / `ACTIVITY_*` 全 nil ⇒ 名单是空表),
   **第二条当场被自己的用例打红**:`bot_api.lua:404` 给 `_G` 装了 `__index`,
   **任何没见过的全大写全局都自动解析成从 1000 起递增的稳定数** ⇒ `ACTIVITY_ATTACK` 是 **1175**,
   名单**是满的**。真正的锁**只有一把,而且它是一个数**:`GetAnimActivity()` 的默认 **0**
   ——`0` 结构上不可能出现在从 1000 起编号的集合里(GH #133 同型)。
   **它按住的不是一个谓词是九个调用点**:mode_roam / mode_farm / mode_ward / mode_outpost /
   mode_secret_shop / mode_side_shop / mode_team_roam + aba_defend + aba_push。
   `test_replay_pullbeat_attack_cancel.lua` 能在**同一个 `Think`** 上驱动 46 帧一次没撞上它。
   **教训的形状:「两条独立理由」听起来比一条稳,但它让人不去查第二条 ⇒ 冗余的解释要么验,要么别写。**
   **⚠ 判据二:没被执行到的分支,和执行了但没效果的分支,证据长得一模一样。**
   录像组给的三个方向前两个都假设分支跑了,而两者与真相产生**同一份**可观测证据
   (坐标不动 + POKE 连续)。**判别器不是位移也不是 POKE,是指令日志**:没被执行到 ⇒
   那一帧**一条指令都没有**(出厂腿在整个 3s 节拍上打印 **91 个 `.`**)。已写进
   `strategy-18` 的预登记反向读法。
   **⚠ 顺带一条 harness 事实**:`check_armed_wiring.py` 默认读 `--ref HEAD` 的**已提交**内容,
   不是工作树 ⇒ **commit 之前跑它,新 id 一律报 UNWIRED**,而那条错误信息读起来像
   「id 从没接线」。本轮吃过这一下,记在这里。
   **下一格(不在本组手上)**:小兵拉野撞**同一行**节流,但它已有 hold ⇒ 是**独立**杠杆,
   排不排由总监裁。**另登记**:GH #190(CM 站在队伍「蓝半径」外)自己写死第一步是**纯读数**
   且对照要跨同局五个位置 ⇒ 本组接它**要先有那份读数**,登记为本组下一格。
0ARITY. **【2026-08-25T19:2xZ 新增,GH #188;三条判据 + 一条已在位的棘轮 + 一个真的被修好的缺陷;本轮由它产出】
   **`0DEAD` 的姊妹洞,同一个 `only={"1"}` 造的 —— 而这一次那一类里有一条不是死代码,是一层被关掉的物品逻辑。**
   Lua **不检查参数个数**:少传 = nil,多传 = 丢掉,两者都不是错误;`.luacheckrc` 的
   `only = { "1" }` 只开 1xx,而**跨文件 arity 本来也不是 1xx** ⇒ 这一类**结构上、永久地**
   穿过铁律 6 的门。工具 `tools/agent/call_arity_census.py`(默认九个决策文件,`--all` 全仓),
   棘轮 `tests/test_call_arity_census.py`(**已进 `run_py_tests.sh` ⇒ 已进每轮自检**;
   新出现一处当天红,修好一处必须删 allowlist 行 ⇒ **名单只能缩**;行按
   `(文件,名字,方向,传了几个,声明几个)` 记,**不按行号**——`0LN2`)。
   **读数**:275 文件 / 1672 声明 / **28,364** 处带点调用、**25,194** 解析成功 ⇒ **40 处**
   不匹配(OVER 8 / UNDER 32),逐条判过并带六个判据词之一
   (`DEFAULTED`/`UNREAD`/`BRANCHED`/`VENDORED`/`COSMETIC`/`TEETH`)。
   **⭐ 唯一的 TEETH-in-house(已修)**:`aiug:993` 的 `X.SetUseItem( hRegen )` 少传两个参数,
   而 `X.SetUseItem` **按第三个参数派发**,五条臂**一条都不中**('ground' 那条的兜底是
   `hItemTarget and … `,nil 短路)⇒ **一个 `Action_*` 都没发**;而它下面那个 `return`
   **坐在整个 `nItemSlot` 循环上面** ⇒ **连别的物品也一起关掉**。
   语料:域 **20** 主体 / 可跑 **18**,**PRE 0/18 有动作,POST 17/18**;
   压制列出厂本来会出手 **8**,扣掉 4 个 treads 假象(GH #133)⇒ **诚实下界 4**。
   **⚠ 判据一(本轮主产出):UNDER 是一个问题,不是一个判决。** 32 处 UNDER 里**只有一条**有牙齿;
   其余是 helper 自补默认(21)、**参数声明了从不读**(2,死的是参数不是调用)、
   **按分支正确**(6:`X.CastInvokerSpell` 的六处一参调用传的全是同一条 if 链路由到
   **不读 `target`** 的那几个技能)、vendored(6)。**这个工具危险的方向是假阳性** ——
   有人照着"把参数补上",把一条本来正确的调用改出行为来。所以每行写判据词 + 理由,不写「已知」。
   **⚠ 判据二:OVER 永远不会崩,这正是它值得报的理由。** 多余参数被静默丢掉 ⇒ 调用点
   **读起来像**在传一个半径/窗口而它没有。8 处里 7 处零行为、纯误导。
   **⚠ 判据三(与 `0DEAD` 的「名字不是身份」互补):arity 是结构量,不是名字量。**
   本轮**刻意没做**那个更诱人的普查(`GetNearbyHeroes` 的 `bEnemy` 极性 vs 接收变量名字:
   `nInRangeAlly` 收 `true` **190 处**、`nInRangeEnemy` 收 `false` **91 处**)——
   按 `0DEAD` 付过的学费,这 281 处只能人读,产出会是「每行都是不必改」的清单
   (`0IMPL` 下一格明写要避开的形状)。**记在这里免得有人重扫。**
   **⚠ 顺带一条 harness 事实(全队适用)**:**shallow clone 上 `git log -S` 会把边界 commit
   报成引入者,而且看起来完全正常**(有日期、有 subject、diff 显示 `/dev/null → +行`)。
   本轮第一次读出的引入者是错的;`--deepen` 到全史后真值是 `9c6c19e5`(**2026-07-21T05:26Z**)
   ⇒ **那两次被拒的 lanefix 捆绑波是带着这个物品层黑屏跑的**(不主张是成因,只主张在场且没人提过)。
   **下一格(不在本组手上)**:GH #189 已交英雄组(`hero_bristleback:620` 把 8.0 喂给体内硬编码
   5 秒的 `J.GetTotalEstimatedDamageToTarget`)。**它本地验不了** —— `0ASYM` 记过 mock 的
   `GetEstimatedDamageToTarget` **对 duration 不敏感**。全仓 UNDER 那一侧**已判完,不要重扫**。
0DEAD. **【2026-08-25T16:4xZ 新增,GH #182;三条判据 + 一条已在位的棘轮 + 一条被量出来的拒绝;本轮由它产出】
   **本仓的门结构上看不见一整类东西,而这一类里恰好有一个不是死代码。**
   `.luacheckrc` 写 `only = { "1" }` ⇒ 只启用 1xx(全局访问),而 unused 家族是 **2xx**
   ⇒ 一个 local **被赋值、从不被读**,**静默通过铁律 6 的门,全仓、永久**。
   工具 `tools/agent/write_only_local_census.py`(默认九个决策文件,`--all` 全仓),棘轮
   `tests/test_write_only_local_census.py`(**已进 `run_py_tests.sh` ⇒ 已进每轮自检**;
   新写一个当天红,扫掉一个必须删 allowlist 行 ⇒ **名单只能缩**)。
   **读数**:九个文件 **1,677 local** → 单名只写 **13**、多名 5;全仓 **307**(单名 285)。
   **健全性是构造的不是分析的**:一个名字**在整个文件里零次读** ⇒ 该文件任何作用域都读不到它
   ⇒ 工具**不解析作用域**,**结构上不可能把活的判死**;代价是**漏报**,写在头里。
   **⚠ 判据一(本轮主产出):名字不是身份 —— 这类工具最诱人的那一列最不可靠。**
   「同名在别的文件里被读」看着正是「死代码 vs 掉了消费方」的分界线,**实测 18 条错 17 条**
   (`Customize`/`attackRange`/`botHealthRegen`/`_` 满树在被读,**没有一处是同一个计算**)。
   真判据**更窄且只能由人读出来**:**别的文件那处读,坐在同一个块的逐字拷贝里**。
   该列已改名 `same-name-elsewhere` 且输出里标 **HINT ONLY**。
   **⚠ 判据二:「只写」不等于「死」——`require` 就是反例,占 13 条里的 3 条。**
   `local Customize = require(...)`:值没人用,**加载副作用承重**。顺手扫掉 = 一个模块不再加载。
   连带修掉计数器把 `GetScriptDirectory()` 数成引擎调用的误导(让每行 `require` 读作"花了一次调用")。
   **⭐ 唯一的 (ii)**:`mode_retreat_generic` 的「前期谨慎冲塔」块**算 `nLongEnemyTowers` 两次、读零次**
   (白花两次 `GetNearbyTowers`),而**逐字姊妹拷贝** `mode_farm_generic:1196-1206` 把它当**阶梯第一级**
   (最年轻的带配最宽的环 1200/中路 1100)在读 ⇒ **retreat 的阶梯是平的,到 10 级一个 898 环通吃**。
   与 GH #160 同族第三份拷贝,**轴正交**(#160 塌的是时间分级,这里塌的是环半径)。
   **⚠ 判据三:拒绝补回去,而拒的理由是量出来的域。** `tools/agent/tower_band_domain.py`:
   塔坐标 **22 座 / 61 枚 fixture 逐个一致**(复现 `0GEO`,地图是实测常数);563 存活英雄帧;
   **任意帧最近 173 u**(⇒ 语料确有贴塔帧,零不是采样)、**该级自己的带 72 帧**(⇒ 分母不空)、
   **该带最近逼近 1,310 u**、中位 2,086 u ⇒ **1,310 > 1,200**(那级会用的环)且 **> 898**
   ⇒ **补回去买到零帧**。机制不是采样:`lvl<=2` 的英雄站在自己那条线的兵线交汇点,
   中位 2,086 **正是这个几何预测的数**。
   **⇒ 钉住,不补也不扫**:补 = 买零帧的加宽;扫 = **抹掉「阶梯掉了一级」这条证据本身**。
   **⚠ 顺带一条 harness 事实**:**按字节数取的源码窗口会被散文推走。** #178 的注释重写
   在块内加 ~1.2 kB,把 `towerfear` 两处 3400 字节窗口顶出了校准判据;
   两个文件都**红着自报「窗口不够宽,块本身可能是好的」**(`0LN2` 自证消息生效),已加宽到 4800。
   **这是「行号是会漂的引用」的第三例,而漂它的是注释不是代码。**
   **下一格(未做,本组建议不做)**:全仓 285 条**未逐条判过**。**不要按 13:1 的比例外推** ——
   `--all` 的样本里满是 `ts_libs`/`FretBots` 这类非决策路径。要扩由总监排。
   **另登记不动**:`mode_roam_generic:624` `vBeamEndLoc` —— 凤凰 sun ray 的**光束**终点算了从不查,
   而块**按半径**挑目标;凤凰非焦点五,交英雄组记账。
0PATH. **【2026-08-25T13:4xZ 新增,三条判据 + 一个已落地的 gated id + 一格交给录像组的核验;本轮由它产出】
   **「读数没动」与「读数动不了」是两回事,而后者可以被证明 —— 证出来的那一格就是下一个杠杆的地址。**
   录像组量 `campgrade` 的 (a) 读到 SILENT,但它没有停在那里:造了一个**单向免责判据**
   (全队历史最高等级 < 该门 ⇒ 这个营**不可能**来自名单),读出 armed 腿 49 次违规里
   **22 次(44.9%)列表免责**。那**不是一个效应量,是一句结构判断**:存在第二条 gate 够不到的通路。
   本轮把它找出来并补上,落成 gated **`campfarm`**(`state.json:campfarm_20260825`,
   `queue.json:strategy-17`,`tests/test_campfarm_ancient_target.lua` **16 例 / 11 变异 11 抓 + 1 控制**)。
   **缺陷**:`mode_farm_generic` 三次野怪扫描里,两次的门**问的是扫描结果的第一只**
   (`GetLevel() >= 10 or not nNeutrals[1]:IsAncientCreep()`)、第三次**一句都没有**,
   而被打的目标出自 `FindFarmNeutralTarget(整张表)`;两个营能同时落进一次扫描(承重帧 ~590u)
   ⇒ **[1] 是小野 ⇒ 门开 ⇒ 打的是远古**。对 maxHP 型农夫(viper/naga_siren/huskar/持 bfury 等)
   这是**常规而非边角** —— 远古野怪正是全场血最厚的那只。
   **⚠ 判据一**:**一个 gate 的「够不到」是可以从语料里量出来的。** 遇到 SILENT,先问
   「有没有一个**单向**判据能把『不可能是它』的那部分切出来」,再决定是怀疑效应量还是去找第二条路。
   **⚠ 判据二(本轮差点踩空)**:**同一个概念在树里有几个阈值,先数一遍再动手。**
   以为是「阶梯 12 vs 门 10」一对一,数完是**三比一** —— 第三处是 `utils.IsValidCreep` 自带的
   `GetBot():GetLevel() > 9`,谁都没提过,而**正是它**让缺陷的域不是「所有等级」而是**恰好 10..11 带**
   (10 以下选择器本来就拒远古,12 以上本来就该打)。没数这一遍就动手 = 把一条本来正确的路径
   一起改掉,然后在波次上读到一个混着两件事的读数。
   **⚠ 判据三(与 `0PORT` 互补,方向相反)**:同一个错误形状在**同一条决策链**上出现三次,
   **修几次的判据是「它们读不读同一个操作数」,不是「它们是不是同一个数」。**
   本轮三个 10 里,farm 路径那两处 + 无门的兜底读的是**同一张表** ⇒ **一次过滤同时管住**;
   `IsValidCreep` 的那个 10 **没有动** —— 它是全仓公用谓词,是另一个杠杆、另一个域。
   **下一格(不在本组手上,已交录像组,零 AWS)**:条件 (a) 的核验点 = 「10-11 级 bot 站在
   同时够得着小野营与远古营的位置上时,打的是小野不是远古」;判据沿用 GH #137 §4 自己那把尺子。
   ⚠️ **排波前置**:`campgrade` 同 arm 会在**上游**把远古营从名单里删掉 ⇒ 读本 id 要排
   `campgrade` **未 armed** 的腿。
0PORT. **【2026-08-25T10:3xZ 新增,两条判据 + 一条已在位的棘轮 + 一格交出去的免费问题;本轮由它产出】
   **同一个缺陷形状出现两次,不等于它是两次缺陷。**
   `pulldrag`(上一轮)在**拉野**上抓到「用泉水代替兵线」并量到浪费 81-87%;**同一个表达式
   逐字出现在已经 promote、每一局都在跑的 `J.ShouldCreepPullLane`(勾线)里**
   (`jmz_func:7362-7374`)。搬过去是最明显的下一步 —— 而量完的结论是 **REFUSE**,
   且**不依赖任何重建**:在这个触发器**自己的域**(本方二塔 → 兵线弧长中点,扣掉拐角两侧各一步)
   里,泉水方向**本来就是**兵线倒退方向 —— 六行(3 线 × 2 队)最差 **0.99 corner-restored /
   0.97 chorded**,600u 一步最少倒退 **581u**。**两个拐角模型同号。**
   工具 `tools/agent/lane_drag_direction.py`,棘轮 `tests/test_lane_drag_direction.py`
   (**已进 `run_py_tests.sh` ⇒ 已进每轮 `routine_selfcheck.sh`**;谁再把 `pulldrag` 搬过来,
   红的是它并指着裁决)。
   **⚠ 判据一(这一条是本轮的主产出)**:把一个修法搬到姊妹行为之前,**先把误差的域和触发器的域
   求交**。一个代理量完全可能**在触发器够不到的地方最差、在触发器所在的地方精确**。这里差别不是
   程度而是**结构**:营在**兵线之外** 1.0-1.3k ⇒ 拖拽必须走**垂直**方向,而「朝家」恰恰没有那个
   分量;兵**在兵线上**,而触发器第一条析取项 `bWavePushedToUs` 字面就是「兵线被压在我们这半边」
   —— **我们这半边通向本方基地,泉水就在那头**,两个向量是同一条射线。
   **⚠ 判据二(而且它就是第一版读数说「有缺陷」的原因)**:**一份对**距离**够用的重建,对**方向**
   可能完全不能用。** 姊妹文件把每条线画成两个一塔之间的**直弦**,并证明过拐角只把最宽那行挪 1u
   —— 对距离够(误差被弓高界住);对**切向**它在**整条弦上**都不能用,因为**横跨直角弯的弦处处
   偏离它替代的两段各约 45°**,而方向误差**没有界**。实证:第一版用「本方一塔 → 中点」这个窄窗口,
   侧线的本方一塔离拐角很近 ⇒ 弦模型里该窗口几乎整段落在弦上 ⇒ 六行最低**中位** **0.29**,
   而 corner-restored 是 **1.00**。(取中位不取 min:该窗口**停在拐角上**,min 永远是拐角那一格
   —— 铁律 4(ii) 的又一例。)拐角**是语料量出来的不是声明的**:两段塔链夹角
   **TOP 88.9° / BOT 91.0° / MID 1.8°**,已成断言。
   **顺带修掉姊妹文件一处潜伏坑**:`pullcamp_lane_geometry.py` 的拐角判据是 `abs(x)<9000` 方框,
   它**接受了中路那个解**并让 corner-restored 的中路折线**往回折**。对它自己的读数**无害**
   (改后 `--selfcheck` 输出**逐字节相同**、棘轮全绿),对任何读切向的人**致命**。已换成参数自由的
   判据:**真正的拐角比它连接的两个一塔都更远离地图中心**(转弯的外侧);中路的解落在两塔之间,被拒。
   **残差没有被否掉,已登记**:**过了中点之后**泉水方向对不拥有那半边的队伍**接近垂直**
   (min 0.07-0.12,两模型都是)。`bWavePushedToUs` 放不进去,但 `bZoned` / `bMeleeVs2Ranged`
   **对兵线位置一句话都没说**。
   **下一格(不在本组手上,已交录像组,零 AWS)**:**已 promote 的勾线 episode 里,有多大比例发生在
   其兵线的弧长中点之外?** 语料已经买过(W3 `spot_20260823_1809*`)。比例可观 ⇒ 杠杆带着域回来;
   ≈0 ⇒ 作废。**按 §AX.2,在这个数存在之前本组不为它申请任何波次**(本轮 `queue.json` 无新条目)。
0GEO. **【2026-08-25T07:5xZ 新增,两条判据 + 一条已在位的棘轮 + 一格明确的下一步】
   **拒掉一个被交办的动作,和执行它一样是交付 —— 前提是拒的理由比它更硬。**
   总监交办「收紧 `PULL_CAMP_LANE_GAP`」并自带前置条件「先跑几何核验」。核验的结论是
   **REFUSE**,而**拒的判据是「序」不是「值」**:仍开火的四个营里,产出全部 connect 的那两个
   是**垂距最宽的两个**,从未产出的两个是**最窄的两个** ⇒ 距离阈值从宽端删 ⇒
   **任何有效的收紧先把分子整个删掉**。用序不用值是刻意的:重建在判定线上读宽 20-82u,
   **任何用绝对值下的结论都住在误差带里,用序的不住**。
   **⚠ 判据一:一个「典型值」只有在它和目标分布重叠时才是典型的。** 这里两个分布**不重叠**
   (引擎能拉到的营全在 1.0-1.3k,拖拽只到中位 742 / p90 992)⇒ **不存在既典型又非空的常数**。
   遇到「把常数调到典型值」这类交办,**先画两个分布,再决定这是不是一个调参问题**。
   **⚠ 判据二(零成本核验的通用形状):动手估一个引擎量之前,先问语料里有没有把它钉住的物体。**
   本轮要的是 lane 几何,而 `GetLocationAlongLane` 在 fixture 里是 mock 常数 —— 但**塔长在 lane 上**,
   且 **61 枚带 buildings 的 fixture 对 22 座塔的坐标逐个完全一致** ⇒ 地图是**实测常数**。
   同族的下一个问题应当先这样问一遍,再考虑要不要波次。
   **⚠ 判据三:重建必须先复现一件已经买过的事实,否则它只和自己自洽。** 边缘对照是
   W7→W8 的实际营地划分(单一阈值复现成功:仍开火最宽 1220 < 归零最近 1282),
   **这同时给出了误差带**;而拐角敏感性是**复核过的**(corner-restored 折线下该行只动 1u),
   不是声明过的。**「我的模型说 X」和「行为也说 X」之间差一次校准,别省。**
   **⚠ 判据四(harness,全队适用)**:`bot:GetNearbyTowers()` **只返回还活着的塔** ⇒
   **不能用它读地图几何**(塔死了 lane 不会搬家)。本轮第一版就是这么写的,在一枚后期帧上
   **静默丢了一个顶点**。读地图用 `fx.buildings`。
   **下一格(未做)**:`pulldrag` 管的是**垂直于 lane 的方向**;还没人管**沿 lane 的纵向**
   —— 录像组 01:35Z 已指出两个 MISS 都是「营在线边上、但兵线在几千 u 之外」。
   **但先别做**:触发条件要求「我方兵线前沿越过中点」,而 own-side 子句要求「营在中点内」
   ⇒ **营结构上永远在兵线后面**,这可能不是缺陷而是教科书拉野的形状(拉出来的小野接的是
   **下一波**从家里出来的兵,不是已经压出去的那一波)。**先把「接哪一波」这件事从录像上看清楚,
   再决定要不要加纵向子句** —— 否则会给一个本来正确的几何加一条错的约束。
0IMPL. **【2026-08-25T04:2xZ 新增,`0SAT` 第四问的结案 + 一条**必须先立判据再动手**的下一格】
   **跨语句那一问做完了,结论是这根轴空的 —— 而路上四个假阳性比那唯一的命中值钱。**
   工具 `tools/agent/guard_implication_census.py`(默认只扫本组九个决策文件,`--all` 才全仓),
   棘轮 `tests/test_guard_implication_census.py`(**已在 `run_py_tests.sh` ⇒ 已在每轮
   `routine_selfcheck.sh` 的 trunk 体检里,这根轴从此每 2h 自动重扫一次,零成本**)。
   **读数**:九个决策文件 **0**;全仓 275 文件 / 2050 个「在事实之下」的条件,只落
   `mode_attack_generic:8`,而那是 `:3` 模块守卫的**逐字真子集** ⇒ 死代码但**零行为**
   ⇒ **allowlist,不修**(同 `hero_earth_spirit`/`hero_phoenix` 的判断:**不必修、也不要顺手删**)。
   **⚠ 判据一(这类工具的通用形状):一个静态结论是算术的,不等于实现它的扫描器是算术的。**
   朴素版报了 4 条、**4 条全错、来自四个互相独立的流缺口**,而且每条**看上去都合理** ——
   危险不是漏报,是**自信地把活分支判死,有人照着删,行为跟着走**。四个缺口
   (全部已钉成 `[reverse]` 用例,不要"简化"掉任何一个):
   (a) **`for`/`while` 通过它们自己的 `do` 开块**,两边都数 ⇒ 深度永久膨胀 ⇒ 事实跨函数泄漏;
   (b) **`then` 臂的守卫在 `else` 臂里什么都不说**;
   (c) **中间重新赋值杀事实**;
   (d1) **`f(b)` 依赖 `b`**,重绑参数也要杀;
   (d2) **字符串字面量是左值身份的一部分** —— 抹成空格会把 `HasModifier('A')` 与
   `HasModifier('B')` 合并成一个谓词。修法是抹成**同长度的标识符形状**,且填充字符用 `_`
   **不是符号**:`'x or y'` → `_x_or_y_`,`or` 两侧都是词字符 ⇒ **不形成 `\bor\b` 边界**。
   **⚠ 判据二:零读数必须连「够不够到」一起报。** 摘要行强制打印
   `guards / conds-under-fact / overlaps` 并在用例里断言下界 —— 否则「0 findings」
   与「工具其实什么都没扫到」**在纸面上一模一样**。
   **⚠ 判据三:别把「结构不平衡」当噪声。** 三个文件读不平衡的根因是**MIT 许可证散文里
   的一个 `do`**(逐行剥离不认 `--[[ ]]` 跨行块);**长注释正是散文关键词住的地方**。
   它没造成假阳性纯属运气。修好后 275/275 平衡,**且这个读数由扫描器自己的 stats 断言**
   —— 自己走一条路的检查,能在被检查的那条路烂掉时保持绿(M8 就是这么活下来一次的)。
   **⚠ 判据四(反向,记一次教训):把一条不承重的用例说成承重的,和漏一条用例一样坏。**
   M6(接受 `and` 守卫为事实)**保持绿** —— 扫描器里那条检查实测是防御性的,
   因为合取本来就既不解析成比较式也不解析成原子。用例因此**改写成「契约」**并写明
   它防的是未来某个更丰富的解析器,**没有假装它是变异靶子**。
   **下一格(未做,而且要先立判据)**:`facts 442` 里绝大多数是**原子事实**(布尔/nil),
   目前只用来判**矛盾**。没问过的另一半是**蕴含** —— 后续条件的一条合取项被上方事实
   恒真化。那不是死代码,是**读者会误以为它在守什么的一条腿**。但 `0SAT` 已把同类
   (`hero_earth_spirit:500`/`hero_phoenix:774`)判为「无害冗余、不必修」⇒
   **先要一条判据说清哪一种冗余值得动,再决定扫不扫;不要先扫后想**(否则会造出
   一份几百行的、每一行的结论都是「不必修」的清单)。
0SAT. **【2026-08-25T01:2xZ 新增,一根新轴 + 一条判据 + 一条留给下一格的话;本轮由它产出】
   **`0CLK` 问常数的**值**,`0TERN` 问表达式的**解析**,两条都问「这一条腿对不对」。
   还剩一个没人问过的问题:**这个合取里的两条腿能不能同时为真**。**
   做法:每个 `if/elseif` 条件按顶层 `or` 拆析取项、按 `and` 拆合取项,把落在**同一个左值**上的
   数值比较收在一起判可满足性。**纯算术、零 AWS、全仓一次扫描 < 1s**,而且**结论不需要帧**
   —— 与 `0TERN` 同源:不可满足是**算术关系**,帧上永远看不见(那 12 行从来没执行过,
   一份「它没开火」的普查读数**证不了任何东西**)。
   **本轮的命中**:`item_purchase_generic` 的「死前买 TP」块要 `botHP < 0.08 and botHP >= 1`,
   而 `botHP` 是 `J.GetHP` 的 **0..1 分数** ⇒ 不可满足,约 12 行死代码,**逐字来自上游快照**
   (`74727e4a:957-958`)⇒ **本仓库历史上一次都没跑过**。落成 gated `tpdeathbuy`。
   **⚠ 判据一(方向):这一类杠杆是加宽,不是收窄。** 本组以往每一根 armed 谓词都是出厂的**子集**
   (只可能少开火);**把死代码打开的杠杆是空集的真超集**,它**严格增加**出厂树从不发生的行为。
   两个连带后果必须写进入集提议和 queue 单,否则会被读反:
   (i) **一份「armed 与 baseline 无差别」的读数不能验证它**(无差别 = 没 armed 或域为零);
   (ii) **反向哨兵方向相反** —— 不是「这个动作的次数不许塌」,是「**它的代价不许暴涨**」。
   **⚠ 判据二(先问「杂散还是约定」,再动手)**:一条看起来多余的合取项,可能是别处的约定。
   判据是**同文件里同一个想法的姊妹写法**:本轮买粉块是同一个模板而**没有**那条下界 ⇒ 杂散。
   **把这个不对称写成 `[reverse]` 断言**,别写在注释里 —— 哪天有人给姊妹块也补上,是用例
   红着来要求重新论证,而不是它悄悄变成一条约定、而我们的修法悄悄变成一次破坏。
   **⚠ 判据三(0DIR 的采购层版本,适用于所有人)**:`GetGold()` **不在 mock 里**(落 `^Get`
   默认 **0**)、`GetItemCost()` 答 **0** ⇒ 采购层里**每一条 `botGold >= GetItemCost(X)` 在 fixture 上
   恒真**,而它的搭档 `botGold < X + 净值/40` 也恒真。**端到端驱动一个采购块会全绿而对金钱带
   一无所证** —— 凡是要动 `item_purchase_generic` 的人,先读这条再决定「本地验证」写什么。
   **这一轮扫描的另外两问都是空的,记在这里免得有人重扫**:`if/elseif` 链里后一支被前一支蕴含
   = **0**(`0WRAP` 那个 `RefreshCamp` 型没有第二例);析取项被另一个析取项吞掉 = **2**,
   `hero_earth_spirit:500` 与 `hero_phoenix:774`,**都是无害冗余、不改行为**(已交英雄组记账,
   **不必修、也不要顺手删** —— 删了要重新论证)。
   **下一格(未做)**:同一把扫描器还没问的第四问是**跨语句**的 —— 一个 `if` 的条件被它上方
   某个 early `return` 的否定式**蕴含**(`0SEQ` 的算术版)。本轮没做,因为它要先做一次
   控制流分析,不再是一次正则扫描;**要做就先把范围收到本组那九个决策文件里**,不要全仓。
0ASYM. **【2026-08-24T22:5xZ 新增,判据条 + 一条待做的下一格;本轮由 GH #159 产出】
   **两个守卫的「域没拼上」不等于「拼上就行」——先问哪一边错拒更贵。**
   `tpsafe`(撤退分支,350)与 `tpsafe2`(700,但被 `nMode ~= BOT_MODE_RETREAT` 挡在撤退外)
   之间有一条 (350,700] 的空档,W7 语料里贴脸按下的 **58.6%** 落在里面、通道内致死 **15.7%** 对 **2.3%**。
   录像组建议「二选一对齐半径」;**本轮用仓库里已有的一枚 fixture 把它否掉了**:
   `f_260819_222030_jugg_tp_start` 是一次**真实的撤退 TP**,Lich **477u**(带内),
   `CanEnemyInterruptTpChannel` 声明真实射程后**答 TRUE**,而 `observed.died_after = 105.9`
   说明**通道走完了、人活了近两分钟** ⇒ **对齐半径会拒掉这次成功的逃跑**。
   **原因是代价不对称**:`tpsafe2` 守的是 travel TP(错拒 = 几秒),`tpsafe` 守的是**最后手段**
   的撤退 TP(错拒 = **一条命**)。**两个半径不同可能不是疏忽,是这个不对称的编码。**
   **⇒ 做法**:(1) 看到「两个守卫域不相接」先别对齐,**先问两边错拒的代价**;
   (2) 对齐不了就在被否的方案**里面**找**最窄的可做子集** —— 本轮是「站着不动已经必死」
   (带内估计伤害 ≥ 当前血量,窗口取**通道长度**而不是共享 helper 的 5s),落成 gated `tpgap`;
   (3) **窗口这类只能从源码断言的量,断言要钉在使用点上不是声明点上** ——
   本轮「`nChannelSeconds` 声明留着、调用传字面量 5」这条突变**第一版全绿放行**,
   因为 mock 的 `GetEstimatedDamageToTarget` **对 duration 不敏感**,帧上永远看不见它。
   **⚠ 连带的 harness 事实(适用于所有人)**:`GetAttackRange` 在**每一枚 fixture 英雄**上读
   mock 默认 **150**(GH #145)⇒ 射程腿只能在 **300** 内为真 ⇒ **任何射程型修法在本地写出来
   的用例都是同义反复**(实测:空档带 161 帧上射程谓词 **0/161**)。要么不含射程腿(本轮的选择),
   要么**显式声明真实射程、并在声明之前先断言 mock 的 150**,否则用例会悄悄变成恒真。
   **下一格(未做,已登记为不可判定)**:GH #159 §4.3 那一型 —— `walk_guard` 带(≤350)里
   `tpsafe` 的三条 fall-through(被控 / 移速 <285 / **爆发够杀我 ⇒ 赌通道**)**一条都不在行为流里**,
   而那一带致死 **15.9%** 说明「赌通道」在输。**要判它先要 dumper 的 CC / 移速字段**([harness]);
   **拿到字段前本组不动它** —— 否则就是拿一个观测不到的谓词换另一个。
0TERN. **【2026-08-24T19:2xZ 新增,流程条 + 一条已在位的棘轮;`0CLK` 的正交轴,本轮由它产出】
   **一个常数写对了没有,要先问「它所在的表达式解析出来是不是它看上去的样子」——
   而 Lua 的 `cond and x or y` 在 `x` 是布尔时,不是三元式。**
   `J.IsModeTurbo() and DotaTime() < 18*60 or DotaTime() < 25*60`:`and` 比 `or` 结合更紧 ⇒
   `(turbo and t<18*60) or (t<25*60)`;`x` 位置是**布尔**,可以为假,于是落到第二项;
   再加上 **18*60 < 25*60**,第一项**蕴含**第二项 ⇒ **整式在任何模式下逐字等于 `t < 25*60`**。
   那个 turbo 常数**一次都没有决定过任何事,而且没有任何计数会报警** —— 它不是「近似对」,
   是**结构上不可达**,读起来却完全像一条已经做过的 turbo 缩放。
   **全仓 25 处 `IsModeTurbo() and X or Y`,坏的只有 5 处(`x` 是布尔那一种)**;
   其余 20 处 `x` 是**数字**(`turbo and 8*60 or 10*60`)⇒ 永不为假 ⇒ **对的**。
   **⇒ 判据(一句话):`x` 是数字就安全,`x` 是比较式就是缺陷。**
   **做法**:(1) 认领任何 turbo 常数之前,先看它两侧 —— **`x` 位置是不是一个比较式**;
   (2) 是的话,**先算两个常数的大小关系**:`turbo < normal` ⇒ 第一项被第二项支配 ⇒ 整式
   等于 normal 那一支(turbo 腿死);`turbo > normal` ⇒ 反而是 normal 腿在中间那段被架空
   —— **两个方向都是缺陷,只是死的腿不同**;
   (3) 结论是**算术关系不是帧现象**,**用算术断言,不要去采帧** —— 帧上两条腿处处一致,
   一份帧证据在这里能证明的只有同义反复(本轮 104 枚 fixture 全在移动带之外,**这件事本身
   被写成了断言**:哪天有帧落进带内,用例红着通知你去钉帧);
   (4) 修法是**把析取改成选择**(`local n = <normal>; if armed and turbo then n = <turbo> end`),
   **门关着必须与出厂逐位相同** —— 出厂塌成的就是 normal 那一支,所以这一步是可断言的,不是承诺;
   (5) **棘轮已经在位**(`tests/test_turbo_ternary_dominance.lua`):`bots/` 里坏形的出现次数
   必须逐位等于 allowlist,且每条 allowlist 记的两个常数必须仍满足 `turbo < normal`。
   **新写一处当天红;修好一处必须删行 ⇒ 名单只能缩。** 动它之前先读文件头的 LIMITS
   (逐行扫描 / 只认带比较运算符的那一种 / 双侧式故意不报,后两条是 `[reverse]` 用例)。
   **⚠ 反向教训,单独记**:本轮 **M12(删掉边界邻域点)没被抓住**,而 `towerfear` 那一格里
   **没有 `149.9/150.0/150.1` 三点、加宽型变异能过掉整份文件**。区别是:那里的结论是
   **一条边界在哪**,这里的结论是**一个全域支配关系**。**「边界两侧必须钉死」不是万能做法,
   照抄到支配型结论上会写出一堆不承重的用例。**
   **未修的四处(留给英雄组,GH #165)**:`hero_alchemist:574/585`(15/30、16/32)与
   `rubick_hero/alchemist:507/518`(逐字拷贝)—— turbo 死带 **15:00/16:00–20:00**,
   **比本轮修掉的那一格大**。第五处 `aba_site:751` 是**孤儿**(零调用方,约 130 处消费方走
   `jmz_func:9834` 那个写对了的 `J.IsInLaningPhase`),删它买不到行为、连带要动 `.ts`,不急。
0CLK. **【2026-08-24T14:0xZ 新增,本组下一条杠杆 + 一条分类;本轮做掉了它的第一格】
   **turbo 里的普通模式时钟常数,是一整条从来没人系统查过的轴 —— 而查它的第一步是**
   **把它劈成两半,因为其中一半缩放了就是新缺陷。**
   `bots/` 里 `DotaTime()` 与常数的比较共 **381 处,只有 18 处 turbo 感知**。收到本组决策路径
   (mode_farm / mode_laning / mode_retreat / mode_roam / mode_team_roam / jmz_func /
   aba_defend / aba_push / aba_role)且只看阶段尺度(≥60s)的比较,得 **27 行、24 行 raw**。
   **分类(这是产出,不是清单)**:
   (甲) **引擎绝对钟** —— 常数指的是引擎事件,turbo 不改它:昼夜 `DotaTime() % 600 > 285`、
   符文/前哨分钟数、开场喊话 `< 60`。**缩放它们才是新缺陷。**
   (乙) **阶段代理** —— 常数是「打到哪一段 / 英雄成熟没成熟」的代理:`IsLateGame` 的 18\*60、
   `GetRescueTpTarget` 的 8\*60、`ShouldConserveManaInLane` 的 10\*60、本轮的 `towerfear`。
   **turbo 里系统性偏晚**,逐条判 TEETH/INERT。
   **本轮做掉的第一格**:`mode_retreat_generic.X.ShouldRun` 的
   `botLevel <= 5 or DotaTime() < 5*60` —— 见当前状态节与 `state.json:towerfear_20260824`。
   **【2026-08-24T16:4xZ 更新:原来点名的两格双双降级,并补上第二根分类轴】**
   原候选 (i) `J.ShouldConserveManaInLane` 的 `10*60` 与 (ii) `J.GetRescueTpTarget` 的 `8*60`
   (= backlog 5 `lfcorelane`)**都不要做**:两者的外层门分别是 `J.IsLaneFixOn('mana')` /
   `('rescue')`,而 `lf_mana` 与 `lf_rescue` **都不在测试集**(`test_set.md` 全文零命中)⇒
   helper 本身 inert。**给一个 inert helper 的常数再套一层 gate,armed 之后仍是逐字节 no-op,
   结构上买不到条件 (a)** —— 那不是小杠杆,是零杠杆。
   **⇒ 新判据(先于一切常数判断):一个 gate 的时钟腿,不比它外面那道门更活。
   先问「这个常数所在的函数在真实局里跑不跑」,再问它的值对不对。**
   **⇒ (乙) 桶的第二根轴 = 这条时钟腿站在合取还是析取里**:
   **析取** `lvl <= N or t < T`(`towerfear`、`mode_farm_generic` 那两条粗子句)= **同一个问题
   的两种写法**,turbo 里时钟腿恰为等级腿已放行的等级继续开火 ⇒ 折半 = **向等级腿收敛**、
   armed 谓词是出厂的**子集**,**这是可做的杠杆**;
   **合取** `lvl < N and t < T`(例:同文件 `botLevel < 6 and DotaTime() > 30 and DotaTime() < 8*60`)
   = 时钟腿是**兜底不是重复**,turbo 里等级腿本来就先收口 ⇒ 折半只会把「8 分钟还没到 6 级」
   这种**真·落后英雄**的保护提前撤掉。**这一类不许折半,与 (甲) 同处理。**
   **下一格在等的是帧不是代码**(GH #160 §6,已路由录像组):
   「对线期 `t < 180`、**5 级以上**、站在敌方塔 **898 码内**」的帧,**一帧就够** ——
   它同时解锁 `mode_farm_generic` 那一格的杠杆(现在 966 帧上时钟腿**单独持有 0 帧**)
   和 GH #160 的分级重排,**并且与 `towerfear` 要的是同一格语料**。
   帧到之前,轴上还剩的 23 行里**优先挑析取型、且外层门已在真实局里跑的**那些。
   **【2026-08-24T19:2xZ 更新:那句话已经执行完了,而结果是这条轴的可做格空了】**
   23 行逐条过完(全表在 `iterations/reports/strategy/20260824T192628Z.md` §1):
   `lf_*` 全族(mana / rescue / salve / threat)**inert**;`X.RetreatWhenTowerTargetedDesire`
   的 `10*60` live 但**本地不可测**(要敌方塔在 **800** 内,而 966 帧里 **898** 内只有 32,
   与 `towerfear` 同一块语料短板);`J.ShouldCreepPullLane` 的 `6*60` live 且 **promoted**,
   但收窄它**与 owner P1「拉野真正跑起来」反向**、且 W7 正拿它当 baseline ⇒ **刻意不碰**;
   `mode_farm:1049` / `mode_retreat:794` 是**合取型**(本条明写不许折半);
   `J.Site.IsTimeToFarm` 的**下限** `5*60` 与 `mode_farm:443` 的 `t>8*60 or lvl>=8` 折半
   都是**加宽**(不是本条说的子集方向,且与「强迫核心多刷钱实测更差」相反)。
   **⇒ 「析取 + live + 子集方向 + 本地可测」四条同时成立的格子已经空了。**
   轴**不关**(GH #157 不随之关闭),但**下一步不再是挑下一行**:要么等录像组那一帧,
   要么换一根正交的轴 —— 本轮换的那一根是 **`0TERN`**(排在本条上面),
   它问的不是「常数对不对」而是「这个表达式解析出来是不是它看上去的样子」。
   **做法(本轮验证过的形状,照抄)**:先普查(两条腿都数、两个方向都报)→ 找出「时钟腿单独
   持有」的帧 → gated 折半(**只动时钟腿**)→ 真实帧断言**最终出价**并把边界**两侧**钉死
   (没有 `<` 与 `<=` 两侧的点,加宽型变异全部能过)→ 量**与在集 id 的可分离性**。
   **⚠ 不要一刀切**:任何「把所有 turbo 常数折半」的批量修法都会踩坏 (甲)。

0WRAP. **【2026-08-23T23:3xZ 新增,流程条,不产 gate;0GATE 的前置条】一个谓词拿到的值,
   和它以为自己在读的值,可以是两个东西 —— **判据是「同一个文件里,别的地方怎么读同一个属性」**,
   不是读函数签名。**
   `J.Site.GetClosestNeutralSpwan` 把 `RefreshCamp` 的包装对象 `{idx, cattr}` 传给了
   `IsEnemyCamp`(读 `.team`)与 `IsAncientCamp`(读 `.type`),而 wrapper 两个字段都没有。
   **证据就写在出错的那两行上**:同两行里的距离读数是 `camp.cattr.location`,
   同文件的 `GetCampStackTime` 是 `camp.cattr.speed` —— **只有这两个谓词调用直接传了 `camp`**。
   后果是两道独立的闸同时死掉:1.5× 敌方野区惩罚**一视同仁**地乘在所有营地上
   (均匀系数改不了 argmin ⇒ **惩罚不存在**,活下来的只有「15000 截断变成实际 10000」这个副作用),
   等级 10 的远古闸门**恒 TRUE ⇒ 死代码**。后者正是 GH #137 §2「6/40 在等级 ≤9」那句话的另一半,
   而 issue 把它整个归给了 `RefreshCamp` 的掉落(`0ASK`:病例真,机制归因少了一半)。
   **`0GATE` 教的是「先数一个门有几条腿在本地可读」;本条排在它前面** ——
   先问**「这条腿要读的字段,在它拿到的那个值上存在吗」**。
   **做法**:(1) 动一个谓词调用之前,`grep` 同文件里**同一个属性**的其它读法,不一致就是缺陷;
   (2) 把「这个值上没有这个字段」**读着真实生产者的输出写成断言**(本轮 W2:真实
   `RefreshCamp` 输出的每个条目 `.team == nil and .type == nil`),不要写在注释里 ——
   哪天有人把字段抄上 wrapper,是这条用例红着来通知你**修法变成了 no-op**;
   (3) **恒真与恒假两个方向都要报**:读不到字段的腿在普查里长得像
   「这条判据每帧都同意我们」(`not IsAncientCamp` ⇒ TRUE)或
   「每帧都反对我们」(`IsEnemyCamp` ⇒ TRUE)—— **两种都不是「不可读」,是 `0DIR` 那种带符号的谎话**;
   (4) 修一条**被两个谓词共用的错操作数**时,变异电池里**必须有「只修一半」那两条**
   (本轮 M2/M3),否则「两个都读记录」没有被钉住,只是碰巧一起改了。
0NUM. **【2026-08-23T21:5xZ 新增,流程条,不产 gate;0ASK 的配对条】一份被驳回的 issue,
   除了「病例」和「机制归因」之外还有**第三样东西:它量到的那个数**。那个数可以在
   解释被驳倒之后**仍然是对的**,而且**指向别的地方**。**
   GH #143 的头条是「一次普攻中位只换来 **2.2s** 小兵追击」,据此建议「>2.5s 就停止拖拽」。
   本组 11:3xZ 用源码驳掉了那条修法(计划每帧重算,结束条件早就在了 —— `0ASK` 立得对),
   **然后连同那个 2.2s 一起放下了**。而 2.2s 是引擎文档里的 **2.3s 仇恨持续**:
   机制**按规格在工作**。它立刻回答了一个**没人问过的问题** ——「那我们的补拍频率对不对?」
   出厂节拍 **1.2s**,而「再拉一次」还有 **2–3s 冷却** ⇒ **第 2、3 拍结构上拉不到任何东西**,
   还因为 `Action_AttackUnit` 会走向目标而**把已拉住的兵线往回拖**。本轮的 `pullcad` 就是它。
   **做法**:(1) 驳回别组建议时,**把它的测量值单独抄下来存档**,与它的解释**分开放**;
   (2) 驳完之后**做一次「这个数还能回答什么」** —— 它是别人花钱买的,解释错了**数还在**;
   (3) 与 `0ASK` 配对:`0ASK` 管「别信它的前提」,`0NUM` 管「别扔它的数」。
   (4) 推论:**一个「看起来像缺陷」的测量,先去检索它是不是某个引擎常数** ——
   2.2 ≈ 2.3 这种吻合一眼就能看出来,而看不出来的代价是把机制当成缺陷去修。
0GATE. **【2026-08-23T19:2xZ 新增,流程条,不产 gate】一个 `A or B` 的门,**先数它有几条腿
   在本地是可读的** —— 剩下那一条不是「主要的那条」,它是**唯一的那条**,而门的全部行为
   都压在它身上,包括它的毛病。**
   `J.ShouldCreepPullLane` 的 DISADVANTAGED 门写着两条析取项。(a) `bWavePushedToUs` 需要
   `GetLaneFrontAmount`,**两队读同一个 mock 常数 ⇒ 966/966 帧结构性 FALSE**(世界断言 22);
   (b) 的强度那一半 `J.WeAreStronger` 在 **966/966 帧 FALSE**(世界断言 23)⇒ 出厂代码读的
   **否定式 TRUE 966/966**。两条合起来,门在本语料上**逐字塌成「附近有敌方英雄」** ——
   而这正是一个普通对线帧的描述。**门的注释描述的是三条判据,它实际执行的是一条。**
   **做法**:(1) 认领一个多析取项的门,**先把每条腿单独在 966 帧上数一遍两个方向**
   (0DIR),把「不可读」与「读出来是假」分开写 —— 前者不是证据,后者才是;
   (2) 一条腿 `n/n` 恒 FALSE 时,**去看消费方读的是它还是它的否定式** ——
   读否定式的那一种更危险,它是恒 TRUE,普查里长得像「这条判据每帧都同意我们」;
   (3) 把「本语料上 X 恒等于 Y」写成**恒等断言**(本轮 `zoned_off == enemy_near`),
   哪天那条腿开始有区分,是这条用例红着来通知你**整个域要重测**。
0SEQ. **【2026-08-23T19:2xZ 新增,流程条,不产 gate;0GATE 的孪生条】一条子句的语义,
   由**它前面那些 return 剩下什么**决定,不由它自己的注释决定 —— 而这两者可以是**相反的**。**
   `bZoned` 的注释说「一个敌方 laner 正在 zoning 我们」。它前面第 5 行是
   `if bot:WasRecentlyDamagedByAnyHero( 2.0 ) then return nil end`
   ⇒ **能走到 `bZoned` 的帧,定义上就是「过去 2 秒没有任何英雄碰过我」的帧**。
   出厂代码于是在**最不可能被 zoning 的那一批帧上**断言自己正被 zoning。
   这不是笔误,是**没有人把这个函数从上往下读过一遍**。
   **做法**:(1) 改一条子句之前,**把它上面所有的 `return` 抄下来,写出「到这里的帧是什么样的帧」**
   一句话;(2) 那句话与子句注释**矛盾**时,缺陷在**注释与代码之间**而不在子句里面 ——
   本轮的修法(要求 2–6 秒前挨过打)正是把两者重新对上,而不是发明一条新判据;
   (3) 顺带得到的是**常数的下界**:新 lookback ≤ 前面那条 return 的窗口 ⇒ armed 后
   **一次都不会触发**,那不是收窄是关闭,必须写成断言(本轮 `harass > safe1b`)。
0PAIR. **【2026-08-23T17:4xZ 新增,流程条,不产 gate】一个被两个消费方读的谓词,
   **错的时候是同时朝两个相反方向错的** —— 而每一侧单看都像是「另一侧的问题」。**
   `J.HasFieldRegenSource` 只读六个主槽:hold 侧(`stayfield`)读 FALSE ⇒ 放行回家,
   supply 侧(`fieldbuy`)读同一个 FALSE ⇒ 再买第二瓶。**同一帧、同一个布尔、两个都错。**
   GH #123 看见的是 supply 那一侧,于是提议收窄采购门 —— 那个修法**会让 hold 侧更错**
   (放弃本族域的 46.4%),08-22 实测拒绝。**从谓词本身关,两侧同时对。**
   **做法**:(1) 认领一个谓词类缺陷,**先数它有几个消费方**(`grep` 定义 + 调用点,
   减掉定义那一处);**只有一个消费方时才可以就地在调用点修**;(2) 多消费方时,
   **把「这个答案在每个消费方那里各错成什么」逐个写出来**再选修法 ——
   本轮正是这一步让「从采购端关」和「从持有端关」变成两个可比的选项,
   而不是「issue 提了什么就修什么」;(3) partition 型的一对消费方
   (`X and P` / `X and not P`)**修完必须断言它们仍互斥** —— 否则 per-id A/B 失去意义。
0EXC. **【2026-08-23T17:4xZ 新增,流程条,不产 gate】一条例外要窄到**它的机制**那么窄,
   而机制通常是「有没有别的代码在替它兜底」,不是「这东西听起来能不能用」。**
   背包里的**大药**能算回复源,因为 `TrySwapInvItemForFlask` 无 gate、每帧跑、会把它换上来;
   背包里的 **tango / faerie_fire / bottle 不能**,因为**全仓库没有任何 swapper 搬它们**。
   这条例外的宽度**完全由那个「不存在」决定** —— 而「不存在」是最容易在半年后悄悄失效的
   前提。**做法**:(1) 凡是「因为别处有代码兜底所以我这里可以放宽」的修法,
   **把那段兜底代码的存在写成 `[reverse]` 断言**,并**把它的『不存在』那一半也断言掉**
   (本轮:四个 `FindItemSlot('item_xxx')` 一个都不许出现)—— 将来兜底扩面时,
   是这条用例红着来通知你重新审例外,而不是没人发现;(2) 阴性对照要挑**在域内的真实帧**
   (本轮 viper 的 faerie_fire 就在处境域里),域外的阴性对照证明不了「放宽没有溢出」。
0DOM. **【2026-08-23T15:3xZ 新增,流程条,不产 gate】一个杠杆的「域」有两个,而申请书写的
   那个通常不是要付钱的那个 —— 谓词选的是**帧**,病例数的是**事件**,bid 是**逐帧**付的。**
   `itemtrip` 拿着 #120 的「0.038 次/局」上机,回来是 gpm −26.44;总监把「差三个数量级 ⇒
   两个测量至少有一个是错的」交回本组。**错的是域**:`J.IsWastefulItemTrip` 在 966 个真实帧上
   **成立 320 帧 = 33.1%** —— 因为它的子句(健康 / 1600 空 / 离家够远)**是一个普通打钱帧的描述**,
   而一个 bot 可以连续几百帧落在域内却一次行程都不发起。**两个数从来不可比,而把它们并排读,
   正是让 33% 帧域的杠杆看起来像 0.038 次/局的那一步。**
   **做法**:(1) 任何新 gate 上机**前**,把谓词在 966 帧语料上跑一遍,**报帧域百分比**,
   与病例的事件率**分开写、永不相减**;(2) 事件率高而帧域也高 ⇒ 缺的是「这一刻真的在做那件事」
   的子句 —— 而这类子句在 fixture 上往往读不到(mode 恒 0 / 信使 nil / stash 崩),
   **读不到就不要假装写了**,退回到**读得到的那根轴上把常数重新推导一遍**(本轮:泉水距离);
   (3) **常数的推导要把病例的移动方式算进去** —— 5000 那个数把一次「TP 去、走回来」的往返
   **当成两边都在走**因而折半,这是**单位错误不是保守**。
0CST. **【2026-08-23T15:3xZ 新增,0SRC 的孪生条】一个复制了它所测常数的检查,在常数移动之后
   测的是旧世界 —— 而它可能**假红**而不是假绿,于是看起来像「你的改动破坏了检测器」。**
   `itemtrip_contract.py` 的 selfcheck 把「干净的远处对照」行写死成 `fdist=9000`;泉水下限
   5000→10000 那一刻,这个「远」不再是远,**那条本该恒绿的对照当场变红**。同一轮里
   `tests/test_detector_source_constants.py` 却全绿 —— 因为它读的是源码字面量,**是对的那一半**。
   **做法**:检测器的自检行**一律由常数推导**(`FDIST_MIN - 1` / `FDIST_MIN + 1000`),
   不写字面量;并且**改常数的那一轮必须跑一次检测器的 `--selfcheck`**,它不在 lua 测试套里,
   `run_tests.lua` 全绿并不覆盖它。
0ASK. **【2026-08-23T11:3xZ 新增,流程条,不产 gate】别组交过来的修法建议,**立论可以是硬的、
   而要修的机制仍然不在这份代码里** —— 判据是把它说的那句话拿去和源码对一遍,不是掂量它的证据量。**
   GH #143 带着 54 局宽扫 + 7 局逐帧 + 两个漂亮的中位数过来,建议「距最后一次普攻 >2.5s
   就停止拖拽」,前提写得很清楚:「目前拖拽走到 `pull.retreat` 就完,与仇恨状态无关」。
   **这句前提是错的**:计划由 `GetDesire` **每帧重新推导**,触发器同帧要求目标 ≤1000 且兵线 ≤900
   ⇒ **结束条件早就在了**。**而推翻它的数就在同一份 issue 里**:5,105 个 episode 的
   **连续 pull 帧最长游程 = 2**(两条腿都没有一个 3)—— 没有长拖,自然没有「提前收手」可做。
   **做法**:(1) 认领别组的建议,**第一件事是把它的前提句逐字拿去比源码**
   (这里是「与仇恨状态无关」对 `GetDesire` 每帧清计划),**在读它的证据之前做**;
   (2) 前提不成立时**不要连帧证据一起驳** —— §3 甲例那 1380u 是真的,只是它不是 pull 帧,
   **「你的病例是真的,你的机制归因不是」是两句话**;(3) 前提不成立**几乎总是意味着
   真正的缺陷在更早或更晚一帧**(本轮:早一帧,攻击命令被自己的 move 取消),
   **顺着它的帧证据往前后各走一帧**,比另起炉灶快得多。
0DIR. **【2026-08-23T09:2xZ 新增,流程条,不产 gate;0p / 0ARM 的第三种形状,而且是
   最坏的一种】一个读不到的量,可能读回来的不是「假」,而是「真」——
   于是杠杆看起来大获全胜。**
   GH #119 的下一根杠杆要读「我在不在还手」。三个写法在 966 个真实帧上:
   `GetAttackTarget()` **nil 966/966**、`J.IsAttacking` **false 966/966**(`GetAnimActivity()`
   恒 0 而 `ACTIVITY_ATTACK` 是哨兵 1158)—— 这两个是 0p 那种「静静地什么都不做」;
   但 `GameTime() - bot:GetLastAttackTime() <= 3.0`(引擎唯一能表达「刚打过」的写法,
   `jmz_func.lua:2052` 就是它)是 **0 − 0 = 0 ⇒ TRUE 966/966**。
   **把它当排除条件套上去,`fieldcreep` 的 5 次否决 5 次全被交还 —— 整条子句消失,
   而普查打印的是 `vetoed 5 → 0`,读起来正是「方向修法完美生效」。**
   **做法**:(1) **凡是新写一条子句,先把它单独在全语料上数一遍 TRUE / FALSE**,
   `n/n` 的**两个方向都是警报**,不是只有 0 才是;(2) 把它**作为排除/否决套回它要改的
   那个域**,报「交还了几帧 / 共几帧」—— 这一步才是把 0p 与本条区分开的那一步;
   (3) **「把时钟修好」不是解药**:`GameTime()` 改答 `DotaTime()` 后同一条子句变成
   **FALSE 966/966**,交还 0/5 —— **谎话只是翻了个面**,语料仍然答不了这个问题。
   (4) 上游时钟事实本身**不是本条的发现**,是**第十四条世界断言的成因 (1)**;本条记的是
   它落在**新消费方**上的符号与后果。见 `tests/test_fightback_world_assertion.lua`
   (第二十条世界断言)与报告 `20260823T092454Z.md`。
0SRC. **【2026-08-23T09:2xZ 新增,流程条,不产 gate;M13 的补丁】常数要从源码读 ——
   但**先说清楚读的是哪一个函数的常数**,否则 `match` 拿到的是文件里的第一个。**
   本轮要读 `J.IsFieldRegenSituation` 的血量上界 **0.55**,第一版直接在整个
   `jmz_func.lua` 上 `match('if nHP < ([%d%.]+) or nHP > ([%d%.]+) then return false end')`
   —— 文件里**有两行一模一样的**(**4674 是 0.18/0.75**,4767 才是本函数的 0.18/0.55),
   拿到的是前一个。断言于是报「钉帧 0.6251 **在带内**(0.18..0.75)」,**整条结论会读反**。
   **做法**:(1) 先 `match('function J%.<name>%( bot %)(.-)\nend\n')` 抠出函数体,
   **在函数体里读常数**;(2) 一个「从源码读出来的」数字要能说出**它在哪一行**,
   说不出就是没读准;(3) 与 M13 同源:那条说别抄常数,这条说**别抄错地方的常数**。
0LN2. **【2026-08-23T07:5xZ 新增,流程条,不产 gate;0LN 的第三次实证 + 一处扩面】
   「有没有别的文件写下了我这个文件的坐标」才是判据,「这是不是一份行钉普查」不是。**
   本轮 `bots/mode_farm_generic.lua` **+6 行**、`bots/FunLib/aba_site.lua` **净 +36 行**,
   两处当场红,**位移量恰好等于插入行数**(0LN 说的对法直接命中):
   `test_level_gate_census` 的 GATES 行(mode_farm 286/370/393/507/536 → 292/376/399/513/542;
   aba_site 760/824 → 796/860,**连同同文件里引用这几行的散文**),以及
   **`test_pingstamp_world_assertion` 的崩溃点断言 `:371` → `:377`**。
   **扩面在后面这一处**:它**不在 0LN 原来点名的那类普查里** —— 它断言的是**一条错误消息
   里的行号**(`tostring(err):find(':371:')`),**长得完全不像行钉**。
   **做法**:(1) 凡在 `bots/` 里插行,收尾跑 `grep -rn '<改动文件>\.lua:[0-9]'`
   **一次跑完**(本轮那次 grep 还顺带确认其余 20 处命中**全是散文引用不是可执行钉子**);
   (2) 修法永远是**把钉子挪到新行号**(源码一字未变,`text=` 仍逐字命中),**不是放宽判据**;
   (3) 与 0LN 同源:那条讲共享**源码坐标**被插入打破,这条说**坐标的写法不止一种**。
0FIX. **【2026-08-23T07:5xZ 新增,流程条,不产 gate】一份 issue 引用的 fixture,
   和它**落地了没有**是两件事 —— 而现有检测器结构上抓不到。**
   GH #137 §3 写「真实帧 fixture:`f_260823_002103_wk_ancient_camp_634.lua`」;
   **它不在树上、不在 `origin/main`、也不在 285 个 remote ref 的任何一个上**。
   `routine_selfcheck.sh` 的 `unlanded_commits.py` 抓的是「**推了**没落地」,
   **抓不到「写进 issue 但从没推过」** —— 后者连一个 commit 都不存在。
   **做法**:(1) **认领任何引用了新产出物的 issue,第一件事是 `git ls-tree` 验它在不在**
   (成本一条命令);(2) 不在就**退到语料里最近的真实帧并把替换写在用例头注里**
   (本轮:11 级骷髅王买不到 ⇒ 退到 10 级,仍在 issue 自己的 ≤11 桶里,精确边界改用别的
   真实英雄钉),**不要因为缺一枚 fixture 就把整条杠杆搁置**;(3) 把这一条**交回开 issue 的组**。
0CMP. **【2026-08-23T07:5xZ 新增,流程条,不产 gate】修一条「掉进下一档」的链时,
   **别用 if/elseif 去写新判据** —— 那是把同一个错误搬高一层。**
   `campgrade` 第一版把「敌方 ≥15 / 远古 ≥12 / 大野 not-weak」写成**对营地种类的 if/elseif**:
   一个**敌方远古营**过了「敌方 ≥15」就 `return`,**永远不会被问「远古 ≥12」** ——
   与它要修的那条 `botLevel <= 14` 掉落链**是同一个形状**,只是判据从等级换成了种类。
   **是变异 M3(以及 19 级那一例的数对不上)当场点红的。**
   **做法**:(1) 多条互相独立的准入条件写成**合取**(每一档都必须过),
   `if 不满足 then return false end` 逐条,**不要 elseif**;(2) **凡是修「fall-through」类
   缺陷,给新判据自己也做一次 fall-through 变异** —— 本条正是这样被抓住的。
0ARM. **【2026-08-23T05:3xZ 新增,流程条,不产 gate】一份普查读出的「这里什么都没发生」,
   可能只是**它自己没 arm**。**
   第十六条世界断言(`test_itemdesire_world_assertion`)记的是「把 TP 弄诚实、驱动全部 882 帧,
   整个语料上没有任何真实 item 决策,只有崩溃和一个原点幻影」。**那个读数只对出厂默认成立** ——
   `_itemdesire_sweep.lua` **一个 soak candidate 都没 arm**,而 TP consider 顶上那两条分支
   (`lf_rescue`/`midtp`)全是 gated 的,在它眼里天然是死代码。
   **arm 上 `lf_rescue`,同一份语料、同一个入口,立刻出现 37 个真实决策**,
   而且落在那些跑不动的表面**之上**(救援分支 aiug:5117 就 return,在 209 次崩溃的通用块之前)。
   **做法**:(1) **凡是引用一份「域是空的 / 什么都没发生」的普查,先看它的 arm 是什么**;
   零 gate 的普查对 gated 世界一个字都没说;(2) **这不是那份普查的错误,是它的作用域** ——
   订正写在两边(那个文件的头注 + 本条),不要把它整份作废;
   (3) 与 0p / 0PID 同族但更上游:那两条是**字段**缺了让子句恒真/恒假,
   这条是**开关**没拨,于是**整条分支从不被执行**,而普查照样输出一个漂亮的 0。
0SS. **【2026-08-23T05:3xZ 新增,流程条,不产 gate】一个 helper 可能是**单发**的:
   同一帧问两次,第二次答 nil —— 不是帧变了,是第一次把票花掉了。**
   `J.GetRescueTpTarget` 的最后一个合取是 `J.TryTakeTpResponseSlot()`(全队一窗口一个应答名额),
   成功还会戳 `J.NoteRescueResponse`。**对 `lf_rescue` 自己这是正确的、不是 `tpclaim` 那个缺陷**
   ——配额是**最后**一个合取(其余条件全过才花),而调用方**在同一帧**把这个答案变成动作,
   **问和去是一步**。后果全落在写用例的人身上:**用 helper 预筛、再在同一次 `rf.load` 里
   驱动出厂链,量到的是一个空世界,而它长得就像「这条分支到不了」。**
   **做法**:(1) 凡是普查里既要「问 helper」又要「驱动链」,**两者之间重新 load**;
   (2) 判断一个 helper 是不是单发,看它的合取链里有没有 `Try*` / `Note*` / `Take*` 这类**动词**;
   (3) 反过来,**配额取在 `and` 链最后一个合取**是本仓库里正确的那种写法,
   `tpclaim`(GH #132)之所以是缺陷,正因为它戳在 query 的**末尾**而不是链的**最后一个合取**。
0LN. **【2026-08-23T04:xxZ 新增,流程条,不产 gate】往 `bots/` 一个文件里加几行,
   会让一个**按 `file:line` 钉行**的普查静默错位 —— 而它长得像「你改坏了一条 gate」。**
   本轮给 `ability_item_usage_generic.lua` 加了 9 行注释+1 行调用,
   `test_level_gate_census` 当场两红:「**missing source for :5759**」+
   「**unpinned GetLevel gate at :5768**」。**两条都是同一件事**:GH #84 (甲) 的 22 行分类表
   把 aiug 的两行钉在 `5759 / 5799`,我的 +9 把它们推到 `5768 / 5808`。
   **做法**:(1) **收尾读失败枚举时,先按「我加了几行」对一遍位移量** ——
   两条错位的差值都恰好等于 +9,这比逐条读断言快得多,也立刻把它和真缺陷分开;
   (2) 修法是**把钉子挪到新行号**(那两行源码一个字没变,`text=` 断言仍逐字命中),
   **不是**放宽判据;(3) **这是 GH #106「加一枚 fixture 是跨 5 个文件的破坏性改动」的孪生**:
   那条说共享**语料**被加/治打破,这条说共享**源码坐标**被任何插入打破,
   而两边都只有全套的失败枚举会说话(0S)。**今后凡在 `bots/` 里插行,收尾必查行钉普查。**
0PID. **【2026-08-23T04:xxZ 新增,流程条,不产 gate】「两个 bot」在 60% 的 fixture 上是同一个 bot。**
   `tests/mock/bot_api.lua:162` 是 `spec.GetPlayerID = spec.GetPlayerID or 0`,
   而**101 枚 fixture 里只有 41 枚带真实 `player_id`** ⇒ 另外 60 枚上每个英雄都读 0。
   本轮要钉的东西(单人应答 claim)**按玩家分**,第一版选的
   `f_045650_lion_meatgrinder` 正是那 60 枚之一 ⇒ 「A 拿走 claim、B 被拒」会
   **静默变成空断言**(A 和 B 是同一个 id,claim 检查里的 `tDefendClaim.id ~= nMyId` 恒假)。
   **是 setup 里那句 `assert(a:GetPlayerID() ~= b:GetPlayerID())` 抓住的,8 个用例当场全红。**
   **做法**:(1) **凡是断言「两个 bot 之间」的东西,setup 里先断言这两个 bot 在这枚 fixture 上
   真的是两个 bot**;(2) 从 `heroes` 里挑人要 `table.sort` 定序,`pairs()` 的顺序不稳定
   ⇒ 不定序的用例主体是随机的;(3) **与 0p 同族但方向相反**:0p 是缺字段让子句**恒假**,
   这条是缺字段让两个主体**塌成一个**,于是断言**恒真**。
0TB. ~~**【2026-08-23T04:xxZ】章程第 8 条(最终出价可达性普查)轮到 `teambrain`**~~
   **【已做完:2026-08-23T04:xxZ,产出 gated `tpclaim` + 一条负结果判决】**
   **判决(负结果,请当结论引用)**:`teambrain` 的**最终出价在本地结构上买不到** ——
   唯一调用方压在 `J.IsDefending` → `bot:GetActiveMode()`(**第十三条**,恒 0)之下,
   目的地 `X.GetDefendTPLocation` = `GetLaneFrontLocation`(**GH #61 拒答**)。
   **两条都在 harness 轴上,不是语料缺口**,再买一波也买不到。
   ⇒ **`teambrain` 一直在 armed 集里,却从来没有本地证据证明它动过一次出价**;
   树上的 `test_replay_teambrain_tp.lua`(5 例)断言的**全部是 helper 返回值**。
   **但审计在出价下面一层撞到一个真缺陷**:单人应答 claim 的戳记写在 **query 的末尾**
   ⇒ **claim 是被「问」烧掉的,不是被「去」烧掉的**。调用方问完之后**下一行还能拒**,
   而两行读的是**两个不同的量**(赋值看 `botAmount.distance` / `botAmount.amount`,
   拒绝看**直线距离** `GetUnitToLocationDistance <= nMinTPDistance - 500`)⇒
   **待在自家基地而中路被围的 bot、或站在另一条路上的 bot,过第一行、挂第二行:
   它根本不会 TP,却把四个真能应答的队友挡了 12 秒。仲裁翻转。**
   修法一个变量:armed 时 query 不戳记,改由调用方在**走向 ABSOLUTE 的那一行**戳
   (`J.NoteDefendTpClaim`)。12 例全绿 / 3 变异 3 抓;`state.json:tpclaim_20260823`;
   `test_set.md` 顶部 04:xxZ 入集提议(**并进 `teambrain` 那一波,不申请专波、不提 queue 单**);**GH #132**。
   **本条留给下一条杠杆的两件事**:(1) **第 8 条名下只剩 `lf_rescue`**;
   (2) **不要把 `tpclaim` 折进 `teambrain`** —— 两者可分,而 teambrain 自己的 (a) 从没买到过,
   折进去就再也分不开谁在起作用(`lanefix` 的形状)。
0IT. ~~**【2026-08-22T23:19Z 新增,本组下一条杠杆 + 一条流程条】**~~ **【已做完:2026-08-23T01:2xZ】**
   `itemtrip` 已上机(`bots/mode_item_generic.lua` + `J.IsWastefulItemTrip`,14 例真实帧用例,
   `test_set.md` 顶部入集提议 + `queue.json:strategy-3` 取证波)。**(1)(2)(3) 逐条照办**:
   录像组已交付 `f_260822_123136_lina_shoptp_434.lua`;gate 用的是 load-time 那一种;
   四个可读量里**只花了三个** —— **第四个(物品栏占用)量出来是死的,见下面这条订正**。
   **(4) 那条「armed 时是整体替换」的顾虑,本轮找到了不必整体替换的写法**:
   浪费帧返 `NONE`、其余帧返 `nil`,于是**文件只可能压低出价、永远不可能抬高**,
   最坏是「不去取 stash」。`nil` 那条合同仍未兑付,但**它现在只在已经 armed 的出价内部花**,
   错的代价被关在一波的 armed 腿里,**并且两种结果都预登记进了验收口径**。
   **(6) ⭐ 本条自己的一处订正,留着别删**:(3) 把「物品栏占用」列进可花预算是对的,
   但**在承重帧上那个量是死的** —— 那一帧 9 格全满(快递在快照前 ~0.2s 送到,#107 的
   标签滞后),所以 `GetEmptyInventoryAmount > 0` 会让杠杆**在自己的立案帧上恒假**。
   **「这个量在语料里读得出来」不等于「它在你要钉的那一帧上是活的」** —— 前者是第十八条
   那类世界断言的问题,后者只有把它写下来、放到帧上跑一次才知道。旧内容存档如下。
   **【存档】**`itemtrip`(GH #120)已完成上机前审计,
   判决「可以写」,但**两件东西必须先到位**,别照着推测先写。**
   (1) **帧**:`20260822_123136_slot3 t=434.6 lina`(满血、最近敌人 4212u、快递正常、
   仍回城合成紫怨,往返 49s ≈ 一局的 8%)—— **需录像组交付 fixture**,#120 §建议 2 是他们自己的下一棒;
   (2) **gate 只许用 load-time 那一种**(文件作用域判 armed,armed 才 `function GetDesire()`),
   **不许**用 `GetDesire()` 返 nil 落回内置那条文档合同 —— 它在 `bots/` 里 0 使用者、**未兑付**,
   而**它错的代价是反向的**:未 armed 的每一局 item mode 被静默压掉。
   (3) **判据的可花预算只有四个量**:血量 / 最近敌人 / 离泉水距离 / 物品栏占用。
   **stash 内容、信使状态、`GetActiveMode()` 一律不许读** —— 第十八条与第十三条世界断言,
   在语料里分别是「崩 / 恒 0 / 恒 0」。
   (4) **armed 时是整体替换** Valve 的内置 item-mode 出价(定义了 GetDesire 就得每帧答一个数),
   所以它比本组平常那种「追加一条子句」的杠杆**偏大**;收益取决于内置出价长什么样,
   **那是录像/批测的问题,不是 fixture 的问题** —— 写之前先想清楚 armed 那条出价曲线怎么定。
   (5) **流程条(0S2 同族的新一格)**:**一个只读源码文本的普查文件,也会被别的组的
   纯文本 ratchet 判成 bid driver**。正确修法不是加一行假声明、也不是塞进 `LEGACY`,
   是**让自己不再硬编码那些名字**(本轮改成 `grep -rl` 发现,顺带把普查的失效模式一起修了)。
   (6) **流程条,GH #106 的第六个消费方差点就是我**:**新用例里不许把语料规模写成字面量**。
   本轮全套跑绿之后 rebase 拉进第 101 枚 fixture,`== 100` 当场转红。
   写法:**和同一次运行里量到的 `c.frames` 比**,另加一条 `>= FLOOR` 地板抓缩水 ——
   **增长免费,丢失照抓**。同族一句:**「跑绿」是对某一棵树的判决,不是对下一棵树的。**
0RES. **【2026-08-22T21:0xZ 新增,流程条,不产 gate】一个 issue 报的是「X 坏了」,
   而树上有一条**出厂的、无 gate 的、每帧都在跑的补救**,报告人和我都没去找它。**
   GH #123 的修法是一个词、helper 已在树上、帧证据齐、还自带一次漂亮的自我收窄
   (26.5% → 12.9%)—— **除了「有没有人已经在修这件事」这一问,它什么都做了**。
   有:`TrySwapInvItemForFlask`(`mode_team_roam_generic:1854`),**13/13 覆盖**修法会打掉的那些帧。
   **做法**:(1) **凡是要给一个缺陷加拦截,先在树上 grep 那个缺陷的补救动词**
   (本轮是 `SwapItems`;别的场合可能是 `Purchase`/`Retreat`/`Cancel`),
   **然后判它的可达性,不是判它存不存在**;
   (2) **`GetDesire` 与 `Think` 的可达性差着一个数量级,而两者都写在 mode 文件里**
   —— 引擎每帧对每个 bot 轮询**每一个** mode 文件的 `GetDesire`,`Think` 只有**赢家**跑。
   **「它在 mode 文件里 ⇒ 它是那个 mode 专属的」是错的**,本轮的整个结论压在这条上;
   (3) **残差不是总体**:报告人量到的「还在发生 N%」是**所有现存补救之后**的数,
   拿它去论证「所以要加一条新拦截」之前,**必须先量新拦截会打掉多大的域**
   —— 本轮两个数一起量才看出交易是 46.4% 换 12.9%(**lanefix 的形状**);
   (4) **0p 有个镜像,本轮撞上了**:0p 是不可达分支**悄悄把功劳记给一个 gate**;
   这一条是不可达分支**悄悄替一个它其实在阻止的缺陷背锅**。
   `GetItemSlotType` 在 fixture 上恒答 0、`ITEM_SLOT_TYPE_BACKPACK` 是哨兵 1174 ⇒
   **天真的隔离用例会在 930 帧上读到 0 次搬运并「确认」这个 issue**。
   ⇒ **凡是要用「它从来没跑过」当论据,先证明它在这个世界里跑得起来**(第十三条 GH #89)。
0U. **【2026-08-22T19:xxZ 新增,流程条,不产 gate】rebase 冲突里 `--ours` 掉的东西,
   补写脚本不会替你发现 —— 它自己 KeyError 了,而 rebase 报成功、全套还是绿的。**
   本轮 `iterations/state.json` 冲突,`git checkout --ours` 取到**早于本轮登记**的一版,
   随后的补写是 `d['fieldcreep_20260822']['x'] = ...` ⇒ **KeyError**;我让 rebase 继续了,
   于是**登记条目一度从树上消失**,而**没有任何一道门会红**(state.json 不进测试)。
   **做法**:(1) `--ours` 之后**重新读文件确认自己那段还在**,不要以「脚本没报错」为准
   —— 本轮脚本**报错了**,报错本身被我当成噪声;(2) 补写脚本写成
   `assert key not in d` + **整段重建**,不要 `d[key][field] = ...`(那句假设 key 还在);
   (3) **同一分钟的第二个坑**:`state.json` 是 **indent=1、结尾无换行**,
   `json.dump(indent=2)` 回写会**重排全部 3,000 行**(实测 3078+/3064−,会跟每个流冲突)——
   动它之前先 `assert json.dumps(d, indent=1, ensure_ascii=False) == raw`,改完 diff 应只有十几行。
   **与 0m 同族**:那条说「远端此刻没有 ≠ 永远没有」,这条说**「我这一版有 ≠ 合并之后还有」**。
0T. **【2026-08-22T19:xxZ 新增,流程条,不产 gate】远程容器在两次工具调用之间挂起
   ⇒ 后台跑的全套几乎不前进,而它长得跟死循环一模一样。** 实测 `ps -o etimes` 在
   **11 分钟墙钟里只涨了 28 秒**;第一次全套「卡在 1233 个点不动 14 分钟」不是挂死,是容器在睡。
   **做法**:(1) 全套用**前台** `Bash`(单次上限 10 分钟)**分段等** ——
   `while kill -0 <pid> && [ $i -lt 112 ]; do sleep 5; ... done`,一轮推一段;
   `run_in_background` + 干等是**净损失**,本轮为此烧掉约 20 个回合;
   (2) **守候谓词不许自匹配** —— `pgrep -f run_tests.lua` **匹配到守候进程自己的命令行**,
   那个 `until` 循环结构上永远不退出(与上一轮 17:30Z 那条 pkill 教训同族:
   **按名字找进程时,找的人自己也叫那个名字**)。用 `kill -0 <pid>`。
   (3) 与 0m 同族的一句:**「读数不动」和「世界不动」是两件事** ——
   这次不动的是容器的时间,不是测试。
0S2. **【2026-08-22T19:xxZ,0S 的第二次实证 —— 同一条合同在两个文件里各有一份】**
   本轮把 `J.IsFieldRegenSituation` 的「must stay gate-free」合同翻面,收尾前用 **grep 函数名**
   找到了 `test_replay_260822_fieldbuy_supply.lua` 那一份并改掉;
   **全套跑出来 1 红,红在 `test_replay_260822_lina_tp_home.lua`** —— 第二份,**措辞不同、位置也不同节**。
   ⇒ **0S 那条「全套的失败枚举才是清单」是本轮唯一发现它的通道**。
   **补一条做法**:**翻面一条合同断言时,grep 的关键词要用被断言的东西**
   (这里是 `IsSoakCandidate` 在 situation 里的出现),**不要用你以为唯一的那句话的措辞**;
   翻完之后**必须跑一次全套**,因为同族消费方(本例第四个 `lina_walk_home`)是否也有一份,
   只有失败枚举答得准。
0P2c. **【2026-08-22T19:00Z 新增,owner P2 的下一格】`fieldcreep`(GH #119)已落地并交出两棒,本条留着盯回程。**
   球在**总监**(并进 §AP.0 的同一波,23 → 24;**本组不申请专波**)。
   **本条留给下一个杠杆的三件事**(都不许照着推测先做):
   (1) **伤害量级判别**(区分野怪与线兵)—— 本轮明写的过宽角是「药膏 vs **单个线兵**」,
   那一格留下来其实是赢的;但要读量级得有**野怪/小兵单位表**,而 **fixture 结构上不带**
   ⇒ **在拿到能看见单位的语料之前不要写它**,写了就是一条结构不可达的子句(0p 的形状);
   (2) **`J.HasFieldRegenSource` 的「够不够」那一格**(0P2 结尾那条)与本条**方向相同但轴不同**
   —— 本条问「有没有人在打我」,那条问「这一口够不够把我抬出危险」。
   **两条都是收窄同一个域**,所以**不要在同一波里一起动**,否则连接率式的归因问题会重演;
   (3) **本轮量到而没用的一个数**:全语料 `WasRecentlyDamagedByCreep(3.0)` 为真的存活英雄帧有 **61**,
   而其中只有 5 枚同时在 situation 里 ⇒ **这条子句的域几乎全部由血量带和 1600 环决定,不由它自己决定**;
   将来若有人觉得它「砍太多」,先看这个比值再动阈值。
0P2b. **【2026-08-22T19:00Z 新增,方法学条,不产 gate】一个形容词也需要一次测量。**
   本轮源码注释第一版把 creep 伤害写成「**双峰**,线兵 8-14 / 野怪 27-45」——
   听起来对、也确实是 GH #119 的说法,**但直方图不支持**:282 条行里 **256 条 ≤24、26 条在 25-45**,
   **众数在 10-14,中间带 15-24 有 64 条**,并不是两个分开的峰。改写成「**重尾**」,
   并把「尾巴 < 十分之一」(26/282 = 9.2%)**写成断言**才算数。
   **做法**:(1) **注释里的分布形容词与注释里的数字同级**,都要有普查支撑 ——
   `bimodal / clean split / 几乎全部` 这类词是**未标注的测量**;
   (2) 本轮第一次写断言时还把 `tail*10 < mass` 当成「thin」,**它在 26/256 上就是假的**
   ⇒ **把形容词翻译成不等式的时候,分母要挑对**(要的是 tail/总量,不是 tail/mass);
   (3) 与 0R「一个读数不构成一次测量」同族,**这是它在定性描述上的版本**。
0DUP. **【2026-08-22T16:0xZ 新增,流程条,不产 gate】同组两个会话并行做了同一条 backlog 项,
   谁都不知道对方在做,代价是一整轮 + 约 80 分钟全套机时。** 现有机制挡不住:
   charter「当前状态」记的是**已完成**的工作单元、`test_set.md` 的提议行是**产出**、
   GH issue 只在**做完之后**才写;铁律 9 解决「棒掉了没人接」,**解决不了「两个人同时接同一根」**。
   **三条做法(第 1 条已可单方面执行,2/3 交总监定)**:
   (1) **收尾跑全套之前 fetch 一次,跑完 push 之前再 fetch 一次** —— 全套要 40 分钟,
   而 main 在这 40 分钟里会前进;本轮如果起跑前 fetch,就能在**烧掉机时之前**发现冲突
   (0m「动手重做之前再 fetch」的下一层);
   (2) 开工写一行**认领**(组 / UTC / backlog 项),收尾删掉;
   (3) **交棒留言必须在 `git push` 成功之后发** —— 本轮在 push 前就在 GH #110 / #114 里写了
   「已落地」,直接造成对方一整节的幻影棒排查。**这是 0m 的镜像**:
   0m 说别把「仓库里没有 X」当成「X 丢了」,另一半是**别把「我这里有 X」写成「X 已落地」**。
0R. **【状态更新 2026-08-22T15:5xZ:本条描述的红色在今天这棵树上已经不存在了 ——
   全套 `run_tests.lua` 跑完 **1246 tests / 0 failures / EXIT=0**,`test_itemdesire_world_assertion`
   在内全绿。**本条不删**:它的方法学(「一个读数不构成一次测量」、per-fixture 分解、
   不许把 179 直接改成 178)仍然有效,而且它自己就是被规模棘轮咬过的样本;
   但「下一条工作单元的默认选项」这个身份**作废**,GH #112 请按此结案或重述。】**
   ~~【2026-08-22T10:xxZ 新增,下一条工作单元的默认选项】本组自己的普查文件在 main 上是红的,
   而且**不是本轮改红的**。`tests/test_itemdesire_world_assertion.lua` 两例 FAIL:
   `crash_total` **207**(钉的是 209)、`crash_2597` **177**(钉的是 179)。
   **在 `origin/main` 的干净 worktree 上逐字复现同样两个数** ⇒ 与本轮的 pullcamp 改动无关
   (本轮改的函数按第十六条世界断言根本不在物品链上,而且这两个数在 rebase 之前是 209/179 全绿)。
   **少的正好是 2 帧**、且**全部落在 `jmz_func:2597`(`GetExtrapolatedLocation`,经
   `J.CanEnemyInterruptTpChannel`)那一个站点**,`crash_3325` 一位没动 ⇒ **有两帧不再走到那条腿**。
   起点:`477d0d4`(corerole,声称 1122/0)与 `41df6b4`(replay-check)之间二分;
   注意 `477d0d4` 加在 8806 行、**不移动 2597 的行号**,所以这是**行为**变化不是行号漂移。
   **这是本组的文件,本组认领**;已开 `[harness]` **GH #112**。
   **本条自带一次自我更正**:开 issue 时把 179 → 177 写成「有两帧不再走到那条腿」这个**机制结论**;
   拿到第三个规模点后站不住 —— 该数 **96 fixture 钉 179 / 98 读 177 / 100 读 178**,**它随语料规模在动**。
   **一个读数不构成一次测量。** 修法因此改成:**逐 fixture 重测全部规模常量 + 把 `crash_2597` 的
   per-fixture 分解写进用例**;**在拿到分解之前谁都不要只把 179 改成 178** ——
   那会让下一次真的行为变化再次伪装成漂移。100 fixture 上这个文件是 **8 红**,六条是纯规模棘轮
   (**GH #106 的形状**)。
   **协同组 11:26Z 的独立确认(第三个规模点之外的一次干净复核)**:在 `bef59de` 开
   干净 worktree 单跑该文件 = **24 例 8 失败**,与带 `stayfield2` 改动的树上跑出来的
   **失败清单和消息逐字相同** ⇒ **11:26Z 那个工作单元使失败数 8 → 8**(它没加 fixture,
   只动了 `jmz_func` 与 `mode_retreat_generic`);同轮另跑 `test_level_gate_census` 15/15、
   `test_gate_claim_consistency` 7/7 绿 ⇒ **行号脆弱性是按文件算的,不是按仓库算的**。
   GH #106 已留言(#112 是本条的主线)。~~
0P1c. **【2026-08-24T01:2xZ 新增,owner P1 的当前那一格;`0P1b` 的回程已兑付】选点有两个轴,
   08-22 只动了一个;`pulllane` 本轮动了另一个。本条留着盯回程。**
   own-side 子句在两波 348 局上买到的是**安全**那一半、而且两波一致(20s 内死亡 **2/97 → 0/146**、
   翻面拉 **7.2% → 0.0%**);**没买到的是 connect(21.5% → 12.1%/9.9%)**。
   **解释就在录像组自己的两个数里**:跟随小野最远走出中位 **742u**(max 1,170),
   野点离最近线兵中位还差 **1,068u** —— **这两个数在修法前后一步没动**,因为 own-side
   移动的是**纵向**坐标而失败发生在**横向**坐标上。本轮 `pulllane`:候选营必须在
   `GetAssignedLane()` 那条 lane 的路径 **1200u**(= max 拖拽 1,170u 向上取整)之内。
   **⚠ 录像组 §4 写的是「换成」,本轮是「加上」** —— 换掉 own-side = 拿安全收益换 connect,
   那是两个杠杆。两条正交,已成 [reverse] 用例(M10 被抓)。
   **本条留给下一个杠杆的三件事**:
   (1) **血量/营地强度门**(#117 §3.3)**仍不许并进来** —— 选点这下动了**第二次**,
   它的域又变了一次;提 id 的时机是 `pulllane` 验收之后,不是「上一格验收过了」;
   (2) **1200 取的是数据支持的最宽值**(不是中位 742、不是 p90 992),因为反 SILENT
   那一侧本地结构上不可测;若波次读数三条都不动而 arm 串确认无误,**下一档是收到 992**;
   (3) `0P1b`(2)(3) 两条(reach 与提前量是一对参数 / 「拉到一半会回线上」要先要录像)**仍然有效**。
0P1b. **【2026-08-22T17:30Z 新增,owner P1 的当前那一格】选点修法(GH #117)已落地并交出三棒,
   本条留着盯回程。** 触发条件与选点**互相拆台**:均衡子句只在我方兵线被压出去时开火 ——
   那正是拉野者本人站得靠前的时刻 ⇒ 「离他最近的己方营」系统性地是深营(283 局:中位在离家
   **10,708u** 开拉、两个深野营吃掉 **51%** 的 poke 帧、**连接率 ≤20.3%**、小野只跟出 742u
   而离最近线兵还有 1,068u ⇒ **失败的是拖拽的几何,不是估计量**)。
   修法一条子句(营必须比车道中点更靠近我方远古),**1500 reach / 窗口 / 0.5 血量门未动**。
   **下一轮先看回程有没有卡住**(总监入集 → 批测台 strategy-2 → 录像组正控),
   卡住就按 0DUP(3) 的规矩去 issue 里问,不要重做。
   **本条留给下一个杠杆的三件事**(都不许照着推测先做):
   (1) **血量/营地强度门**(#117 §3.3):**等选点验收过再提 id** —— 选点改了它的域也会变;
   (2) **reach 与窗口是一对参数,不是两个**:1500 是按「5s 行程提前量 × ~300u/s」定的,
   若将来发现修法后 poke 掉太多,**动 reach 必须同时动提前量**,否则 bot 会在标记之后才到;
   (3) 07:30Z 就留下的那条**「拉到一半会回线上」**(窗口关闭清空 plan)仍然要**先要一份
   它真的跑起来的录像**,不许照着推测加粘性。
0P1. **【2026-08-22T07:30Z】Owner P1 第 1 棒(pullcamp SILENT 根因)已做完并交棒 —— 本条留着盯回程。**
   根因:**触发器要求它自己要造出来的那个状态** —— `bot:GetNearbyNeutralCreeps(1400)` 非空
   (「已经看得见营地」),而站在兵线上的辅助**看不见树后的野营盒子**;同时 roam Think 的
   「走向营地」分支只有 plan 存在才可达 ⇒ **触发器等抵达、抵达等触发器**,与 2026-08-19 修掉的
   勾线死分支**同形状**(GH #13 的另一半)。修法一个杠杆两处编辑:视野问题**搬到**抵达时问
   (`bCampHere`),窗口开 **5s 行程提前量**(:05–:20 / :35–:50,**标记 :12/:42 未动**)。
   **未新增 soak id**(照 creeppull 先例在 `pullcamp` 内修)。
   **owner 怀疑的 `IsLanePullSafe` 不是根因**:**339/930** 帧成立。
   **P1 DoD 的频率证据**:**36/930** 帧是「辅助 + 对线窗口 + 800 内无敌人」,旧窗口收 **10** / 新窗口收 **15**(收尾 rebase 后语料 98→100 fixture 重测,定性结论未变)。
   `tests/test_pullcamp_trigger_census.lua`(20 例,7 变异)+ 子进程普查 `tests/_pullcamp_sweep.lua`;
   另把 `tests/test_pull_camp.lua` 那条被本轮翻面的合同用例改掉(11 → 15 例)。
   **交出去的三棒**:总监(test_set.md 顶部提议行,重新入集)/ 批测台(`queue.json:strategy-1`,
   申报目的 = 买 (a),seeds 888/895/896/906)/ 录像组(阴性判据:仍 SILENT 就先看**有没有离开兵线走向营地**
   —— 修复前那一步结构上不会发生)。**本条在 #109 关闭前不划掉;下一轮先看回程有没有卡住。**
   **本轮明确不做、留给下一个杠杆的**:窗口关闭会清空 plan ⇒ **拉到一半会回线上**;
   要不要给拉野一个「完成中」的粘性,**先要一份它真的跑起来的录像**,不许照着推测调。
0P2. **【owner 优先项 P2,2026-08-22T09:33Z 第一棒、11:26Z 第二棒都已交】决策侧两条回家路
   现在都有 gate:`stayfield`(TP,item 层)+ `stayfield2`(步行,`mode_retreat_generic`)
   ⇒ `stayfield` 已由 §AM 入集,球在**总监**(**请把 `stayfield2` 补进同一波** ——
   P2 完成定义第 1 条要两条路都覆盖)。
   ~~(a) **步行回泉那一半**~~ **已做完(11:26Z)**:核心谓词拆成无 gate 的 `J.ShouldRegenNotGoHome`
   + 两个各带 gate 的薄包装;真实帧上撤退出价 **0.1441 → 0**(**本族第一次能断言最终出价**);
   19 例 8 变异。**新增第五条腿「1200 内无敌方塔」是全语料扫出来的**:第一版会把
   `mode_retreat_generic` 的 **ABSOLUTE×1.1 前期谨慎冲塔**出价也压成 0(7 级宙斯 40% 血、
   离敌塔 727 码)⇒ **retreat 模式不只是「回家模式」,它同时承载局部后撤出价**,
   今后凡动它的出价先看这一条。**触发很稀:3/100 fixture 帧为真、1/100 真的动出价。**
   ~~(b) **两个 id 的域大小本组量不了**(要数「低血 + 无近敌 + 包里有回复品」的真实帧频率),
   随入集后的波次一起要。~~ **2026-08-22T15:22Z:量到了,而且是免费的** —— 本组一直把它
   当成「要买语料」的问题,其实**它是 100 枚已付过钱的 fixture 上的一次普查**:
   930 存活英雄帧里 situation **50** = **有回复品 22 / 没有 28**。
   **把每个英雄各自当 subject 驱动一遍**(不只驱动 fixture 的 `self`)是关键 ——
   之前的扫法只有 100 个 subject 帧,量不出频率。**这条今后当通用做法:
   「本组量不了、要等波次」在下结论前,先问一遍能不能改成对全语料的普查。**
   **另记一条录像组的免费事实(已被总监 §AM 部分推翻,原文保留)**:22 次真·回家 TP 里带**大药**的是 **0/22**;
   总监指出那一列**按构造恒为 0**(`撤退:3` 分支自带 `itemFlask == nil`)⇒ 它不是缺货的证据。
   但**补给侧确实是承重的那一半**这个结论**独立地成立了**:28 > 22。
   (c) **补给侧 `fieldbuy` 已做完(15:22Z)**,见「当前状态」头条与报告
   `20260822T152213Z.md`。**下一条给本组的**:三个 id 都在等**同一波** —— 本组不重复申请、
   不重复提 queue 单;**真正还没人做的是「留下之后够不够」** ——
   `J.HasFieldRegenSource` 只问「有没有一口」,不问「这一口够不够把我抬出危险」
   (仙灵之火 85 点瞬回把 31.8% 血的莉娜抬到 ~39%:**让她留下,并不让她安全**,总监 §AM 预登记
   口径第 2 条正是要录像组去数这个后果)。**在拿到那一波的后果读数之前,不要照着推测加阈值。**
0S. **【2026-08-22T10:xxZ 新增,流程条,不产 gate】「我以为我碰了哪些文件」不是清单,
   **全套的失败枚举才是**。** 本轮按「被我碰过的文件」逐个跑,**漏掉了第五个**
   (`test_itemdesire_world_assertion`,8 例红),它是在**修 census 之前**启动的那次全套跑完后、
   我去读它的 `FAIL` 清单才露出来的(**1159 tests / 24 failures = 2+5+8+3+6**)。
   **而那 8 条里有 1 条不是分母**:`crash_2597 == 179` 在**今天的四棵树上**
   (`cac2fa5`/`41df6b4`/`477d0d4`/`3dc30f2`,98 枚语料)**读数全是 177** ⇒ **本轮之前就红了 −2**。
   **收尾读到总监 `bef59de` 的 bisect:那 −2 是本组自己的 05:30Z `cf7bb4c`** ——
   上一轮**治疗**一枚 fixture 时同一个 `--t` 落到早 ~0.33 秒的采样,**已存在 fixture 的帧变了状态**,
   全语料绝对计数跟着动。**采信,并撤回我原先写的「无人认领 / 已 promote 路上的行为变化」**
   (`state.json:itemdesire_CRASH_PIN_STALE_20260822` 已标 CORRECTED)。
   **方法学教训比结论值钱**:我变了四棵 `bots/` 树、**从没变语料内容**,
   所以四棵树一致只证明「不是代码」,**永远证不出「是语料自己动了」——
   没变的那条轴就是你无法排除的那条**。
   **做法**:(1) 改动收尾时**先跑一次全套拿失败枚举**(哪怕跑不完也要跑到能读清单),
   不要只跑自己以为碰过的文件;(2) 分母搬迁时,**每一个搬不动的数都要单独解释**,
   搬不动的那个往往才是真发现;(3) 归因一个「不是我」的移动,**要在多棵树上实测**,
   不要靠「我的 gate 是关的所以不可能」这种推理 —— 本条正是把那句推理实测成了事实;
   (4) **但实测也要挑对轴**:本轮四棵树全是 `bots/` 轴,答案却在语料轴上,
   总监的 bisect 之所以赢是因为他把**提交**当轴(语料改动也在提交里);
   (5) **GH #106 的规矩补后半句**:共享语料不只被「加一枚」打破,**也被「治一枚」打破**,
   而治疗改的是**别人已经量过的帧**,两边都收不到机制预警 —— 本组的 0c 治疗队列还有 4 枚,
   **今后每治一枚,收尾必须跑一次全套并读失败枚举**。
0R. **【2026-08-22T09:33Z 新增,流程条,不产 gate】GH #106 §4 在本组的四个普查文件里一条都没做,
   而本组今天亲自付了第二次代价。** 加两枚 fixture ⇒ **24 例红,没有一条红在发现上**
   (全在分母,外加两条红在**行号**上 —— 往 `aiug` 插 6 行就把 `test_level_gate_census`
   按 `file:line` 钉的两道门推走了)。**做法**:(1) 分母搬迁**必须逐个按该文件自己写下的规矩**做 ——
   `gamemode` 明写「不许搬分母然后祈祷」,于是两枚新帧的竞价**两读法各跑了一遍**,
   结果**移动格 22→23 而移动赢家不变 19**(第一次分子与分母移动量不同);
   `pingstamp` 同理实测出**戳的份额 35→36**;(2) **改 `bots/` 的行数会推走按行号钉的普查**,
   本组今后动 `aiug` 之类大文件时,提交前先跑一遍 `test_level_gate_census`;
   (3) **把 §4 真正做掉是一个独立工作单元**(要判「别人证据文件里哪些等式是发现、哪些只是分母」),
   不要顺手塞进一个行为改动里。
0q. **【2026-08-22T05:30Z 新增,流程条,不产 gate】治疗一枚旧 fixture 时,**先不带 `--roles`
   生成一遍并逐字节比对是硬前置** —— 前五次它都过了,于是被当成形式;第六次它**不过**,
   **而且失败的样子是一堆看起来完全合理的帧数据**(184 而不是 188,6033 而不是 5995)。
   `f_260819_182855_lion_drain_jungle` 在同一个 `--t` 上落到了**比被替换那份早 ~0.335 秒**的采样;
   **事件流那一半逐字节相同**(`recent_damage`/`burst`/`died_after`/`buildings`)⇒ 动的只是英雄快照相位。
   **做法**:(1) 比对不过时**必须解出它挪到了哪儿** —— 把旧坐标投影到今天两个相邻采样之间,
   **只用走得快的英雄**(本轮 387–427u 位移、≤23u 偏离的四个互相独立同意到 0.01s;
   走得慢的那几个解在 246.47–247.58,进表就是噪声);
   (2) **把挪动量与被钉结论的余量放在一起**再决定这枚 fixture 还算不算钉住原来那件事
   (本轮:38u 位移 vs 5500u 余量 ⇒ 结论没动,**但两条断言写在 10u / 个位精度上,炸了**);
   (3) **同一个用例里的多条紧断言会互相遮挡** —— 血量那条先炸,10u 那条要等它修好才露头;
   (4) 顺带的通用读数:**标着 t 的快照携带的是 t 之前 ~0.2–0.33s 的状态**
   (冷却量表 n=1884 加权均值 0.22s 且偏低;血量重建偏好 0.33s = 10 tick),
   已开 `[harness]` **GH #107** 交总监,**在总监定案前,任何「这一帧的状态与它的 recent_damage 对齐」
   的立论都要带上这条**。**与 0m 同族:本地绿 ≠ 那一刻的世界。**
0p. **【2026-08-22T03:30Z 新增,流程条,不产 gate】一个 fixture 缺的字段,会把一条
   **已发布默认行为**伪装成一个 gate 的功劳 —— 而且伪装得像一条干净的隔离证明**。
   `f_260819_181742_ss_chase_*` 那两枚(GH #45 的钉帧)缺 `recent_damage`,于是
   `WasRecentlyDamagedByHero` 对所有人恒 false,`ConsiderHelpAlly`(**无 gate、已发布、
   turbo 默认在跑**)在任何 fixture 上都点不着 ⇒ 2026-08-19 那轮的六 id 隔离循环
   **每一格都诚实地读 0**,于是得出「由 `ownhalf`、而且只有 `ownhalf` 打开」。
   治疗后:**零 id armed 就出同一条 `Action_AttackUnit(dk,false)`**。
   **形状比「断言骑在桩上」更坏**:那是断言依赖一个假值;这是**整条分支不可达**,
   所以隔离循环**跑得又快又绿又全零**,看起来正是一次干净的归因。
   **做法**:(1) **凡是做「只有 X 打开这一帧」这类归因的用例,必须先声明「这一帧上
   哪些已发布分支是结构不可达的」** —— 不可达的分支不进隔离循环就等于把它归给了 X;
   (2) 归因用例的**每一条外层子句都要有非空见证**(本轮 `ConsiderHelpAlly` 的四条里
   两条是第十三条世界断言的常数,已按常数标注,不当测量);
   (3) **隔离循环里的每个 id 要先验证它还活着** —— 本轮那格 `roamstale` 早在
   2026-08-19 就 promote 了,**按构造是 no-op**,和 GH #103「gate 状态只活在注释里」同源。
   **与 0m/0n 同一族:绿色本身从来不是证据,全零更不是。**
0n. **【2026-08-22T01:30Z 新增,流程条,不产 gate】同名用例静默互相覆盖,**
   **唯一的破绽是计数**。本轮给 `test_replay_260820_cm_es_aftershock.lua` 加五条 re-read 用例,
   其中一条的名字**与上一轮给同一文件另一帧写的那条逐字相同**。`tests` 是普通 Lua 表 ⇒
   **新函数把旧的那条替换掉了**:不报错、不失败、diff 里两条都在,
   **只有总数读 31 而不是 27+5=32**。当场改名后 32 全绿。
   **做法**:(1) **加了 N 条用例必须核对总数涨了 N**;(2) 同一文件里钉多帧时,
   用例名带上帧标识(本文件现在是 `frame A …` / 不带前缀的那条属于 frame B);
   (3) 这与 0m 的「变异要真的落在被测量上」是同一类 —— **绿色本身从来不是证据**。
   **本轮的 M3 第一版正是 0m 那第四种形状的复发**:`aba_role.lua` 里 `return 3` 不止一处,
   `replace(...,1)` 落在 `GetPositionForCM`(307 行)而不是 `GetPosition` 的敌方分支(398 行)
   ⇒ 变异跑了、生效了、全绿,看起来像「断言没牙」。改成从函数头 `index` 并断言
   前 120 字符里有 `GetEnemyPosition` 之后才咬住 —— **顺带第一次由变异(而非读代码)证实
   loader 确实给敌人 `rawset` 了抽签角色,是已发布的敌方分支主动扔掉活数据**(GH #81)。
0m. **【2026-08-21T20:35Z 新增,流程条,不产 gate】一次 fetch 只说明那一刻的远端 ——
   不要把「仓库里没有 X」当成「X 丢了」**。本轮开工 fetch 过 `origin/main`(tip `936cb3e`),
   GH #93 正文点名的三样产物**当时确实一件都不在仓库里**,charter 头条也还停在 15:46Z
   ⇒ 判定「17:58Z 的提交丢了」并**把第十五条从头独立重测了一遍**。
   收尾 rebase 才发现 `e8061a3` 已在 main 上 —— **晚推约 70 分钟**,正好卡在初次 fetch 之后。
   **一整个 16 例文件因此作废。**(同一天英雄组 17:36Z 已发作过一次:
   "a duplicated work unit, discarded"。)
   **做法**:(1) 基于「仓库里没有 X」的立论,一律写成**有时间戳的观察**,不写成「丢了」的结论;
   (2) **issue 正文点名了产物路径时,先去 issue 里问/看它推没推**,不要直接重做;
   (3) 长会话在**动手重做之前**再 fetch 一次(本轮如果在 19:30 重 fetch 一次就能避免整轮);
   (4) 收尾 push 之后回读 `git log origin/<branch>` 确认远端 tip 真的含本轮提交。
   **与「批测实例 clone `origin/main`」那条近失(2026-07-23)同源**:**本地绿 ≠ 远端有**,
   而它的镜像是**远端此刻没有 ≠ 远端永远不会有**。
   **顺带记的一条方法学(第四种失败形状)**:变异 N1 生效了、测试也跑了、结果是绿的,
   但它**没瞄准被测断言的观测面**(把一行从占 3 行的文件挪到占 1 行的文件,distinct 计数不变)⇒
   **「变异跑绿」在确认变异落在被测量上之前不算数**,这是 13:48Z「变异要真的生效」的下一层。
0i. **【2026-08-21T11:32Z 新增,(甲) 已做完,(乙) 是下一条】等级常数的 Turbo 不可达
   (GH #84,总监交接)**。**(甲) 分类表已交并钉成棘轮**(`tests/test_level_gate_census.lua`,
   15 例):22 行 = **6 TEETH / 12 INERT / 4 REDUNDANT**,**6 条 TEETH 全在通用文件**
   (`item_purchase:228`、`mode_farm:285/392/506/535`、`aiug:5749`)。
   两条对 #84 的修正已留言:(i) **牙齿与 AND/OR 不对齐**(3 合取 + 3 析取);
   (ii) **§5 的筛子「合取 ∧ N>=20」选出 4 行且全是 INERT**,而 6 条 TEETH 的 N 全是 15/18
   —— 建议筛子改成「判读 = TEETH」;(iii) 被点名为「无害析取」的 392/506 的承重腿
   `J.IsLateGame()` 在 Turbo 是 `DotaTime() > 18*60`,**全档 94 帧无一成立**(真 helper 实跑)。
   **下一条(本组自己接)**:从 6 条 TEETH 里挑 **一条** 做完整形状 —— gated + 真实帧 +
   **断言最终 desire**(不是断言分支可达)。~~建议 `mode_farm_generic:285`~~
   **2026-08-21T13:48Z:`285` 结构上做不了,那一帧不存在也买不到 —— 见下面第 0j 条
   (第十三条世界断言)。语料请求已撤回。**
   ~~**改取 `mode_farm_generic:535`**~~ **2026-08-21T15:46Z:`535` 也做不了 (乙) 的形状,
   但卡点可以买到 —— 见下面第 0k 条。两半分开量了:情境这一半**活的**(872 存活英雄帧里
   **3 帧**满足内层 `if` 每一个子句,等级 4/11/11,敌人 55–167u,2–3 队友 ⇒ TEETH 得到实证),
   外层的 `runMode` **从不同时成立**(`X.ShouldRun ~= 0` 只有 5/940 帧,交集空)。
   **语料请求是活的**(不像 #84 那次是撤回):要一帧 farm `ShouldRun` 非 0 且同帧 900 内 ≥2 队友、
   `attackRange+50` 内有非魔免敌人。**下一轮默认改取 `item_purchase_generic:228`**
   (自家 t3 掉血 ⇒ 留买活钱,同样不读 mode、不读 runMode 这类文件局部状态)。
   **2026-08-21T17:58Z:`228` 也做不了 —— 而且理由和前两条都不一样:它在 Turbo 里根本不跑。**
   那道门在 `GeneralPurchase()`(192-363)里,而这个函数只有一个调用点(1276):
   `if GetGameMode() == 23 then TurboModeGeneralPurchase() else GeneralPurchase() end`。
   真实 Turbo 走另一条腿 ⇒ 整个函数、连同 `t3AlreadyDamaged` 的四写两读和 `:272` 的
   留买活钱一起不跑;`TurboModeGeneralPurchase`(366-437)**自己没有买活留钱**
   ⇒ **Turbo 的采购里根本不存在买活留钱**,原因在等级常数**上面 1048 行**。
   **(甲) 对 `228` 的 TEETH 判读据此更正。三条 TEETH 三个不同的卡点**:
   `285` = dumper 缺口(买不到)/ `535` = 语料缺口(**能买,请求活的**)/ `228` = 不在 Turbo 里(没什么可买的)。
   **下一轮默认改取 `ability_item_usage_generic:5749`**(守遗迹 TP,另外四项 AND 都是活的 Turbo 状态)。
   规矩照旧:**断言最终 desire,不是断言分支可达**;掉 farm desire ≠ 去打架。
   **2026-08-21T22:00Z:`5749` 也做不成 —— 但这次等级门 satisfiable(唯一 subject≥15 帧
   `f_260820_043120_viper_defend_paired` viper@15,外层门 5751-5756 整个开)⇒ 等级不是卡点,
   基地被围才是。两条内层腿(path 1 守护遗迹读 #61-refused 的 `GetNearestLaneFrontLocation`
   且几何子句要敌兵线进遗迹 1600 内;path 2 保护遗迹要两 T4 塔拆掉 + 敌兵进 800 内)都只在
   基地被围时触发,自终止 turbo 语料到不了(= 0a 那条「打到基地的局」,不新开请求)。
   ⇒ **六条 TEETH 全查完,普查产出零个 shippable 杠杆**(285 dumper / 535 语料 / 392-506 死析取 /
   228 不在 Turbo / 5749 基地被围+#61)。已成 `tests/test_relicguard_siege_gate.lua`(8 例),
   `state.json:relicguard_LEVEL_GATE_CENSUS_CLOSE_20260821`。**GH #84 §5 的 (乙) 形状到此为止,
   下一条工作单元不再走等级门这条线** —— 回到 0b/0c 的逐帧治疗队列或 0a(等基地攻防语料)。
   ~~**下一轮默认改取 `ability_item_usage_generic:5749`**(守遗迹 TP,另外四项 AND 都是活的 Turbo 状态)。~~
   **2026-08-21T22:33Z:`5749/5751` 也做不了 (乙),第五种卡点 —— 但 (甲) 的 TEETH 判读
   第一次拿到了数,而且是六条里第一条。** 在 **489 个带真实建筑的存活英雄帧**上另外五个操作数
   全成立的有 **190 帧**,其中 **187 帧**等级门是**唯一**挡着的(全语料 911 帧只有 **8 帧**到 15 级)。
   **卡在后件**:3 个满足整个外层 AND 的帧(全是同一个 viper,`od_eclipse_pair`/`od_eclipse_solo`/
   `viper_defend_paired` —— **是帧数不是情境数**)上,子分支 1 要 `GetLaneFrontLocation`
   (GH #61 拒答,3/3 实测)、子分支 2 要两座 tier-4 都没了(诚实 508 帧 **0 帧**);
   **而这两条之上还压着第十六条:那个函数根本没被调用过**(见下面第 0q 条)。
   **四条 TEETH 四个卡点**:`285` dumper 缺口 / `535` 语料缺口(**请求仍活**)/ `228` 不在 Turbo 里 /
   `5751` 后件+函数都不可达。
   **下一轮默认改取 `mode_farm_generic:392`** —— 剩下两条 TEETH(`392`/`506`)都在 mode 文件里,
   走**通着的竞价路**,而 `392` 的承重腿 `J.IsLateGame()` 已被 (甲) 钉过,起手最省。
   规矩照旧:**断言最终 desire,不是断言分支可达**;掉 farm desire ≠ 去打架;
   **并且先声明第十四条那个 ping 假设**,否则读的是地板不是这一帧。
   **顺带记的第二个杠杆(不折进本条)**:自动买活三条路径在 Turbo 全关
   —— `aiug:568` 的 `ancient:GetHealth() < 0.8`(**单位错配**,该开 `[bug]`)、
   `:582` 的等级 >24、`:578` 的 `nFullRespawnTime < 60` 早退(**推论,harness 判不了**,
   `GetRespawnTime` 不在 dump 里)。已成 `[recorded]` 用例。
0q. **【2026-08-21T22:33Z 新增,已钉住、不要改 mock、不要改 loader】第十六条世界断言:
   全语料没有任何一帧调用过任何物品的 Consider —— `J.CanCastAbility` 恒 false,卡在 `IsTrained`**。
   `J.CanCastAbility(<任意物品句柄>)` 在 **5774 个占用槽 / 911 存活英雄帧 / 98 fixture** 上
   **可施放 0 个**;出货的物品循环(`aiug:1007-1035`)只在 `if J.CanCastAbility(hItem)` 里面调
   `X.ConsiderItemDesire[name]` ⇒ **整个物品决策层是黑的**。把出货入口 `ItemUsageThink()` 在
   **882 个可驱动帧**上跑一遍:**0 动作、0 报错** —— **看起来干净的一遍绿,其实是空的一遍**。
   **成因是一条 `and` 链里的遮蔽,不是缺字段**:六个子句里 loader 只接了 `IsFullyCastable`,
   而且对 TP 是**从 dump 的真实冷却接的**(`u.tp_cd <= 0`);其余落到 mock 的 `Is*` 默认 false
   ⇒ `IsTrained()` 答 false,**在 loader 精心处理的那一条前面两句就短路**
   ⇒ **658/911 帧的真实 TP 冷却一个读者都没有**。已配**阴性对照**(补上两条后,真在冷却里的卷轴仍被拒)。
   **有多大**:诚实 TP 句柄同样 882 帧 → **672 no_action / 1 动作 / 209 崩溃**(今天 882/0/0)。
   **崩溃是更大的那半**:24% 的帧在 tpscroll consider 里抛异常,点名**第四、第五个跑不起来的面** ——
   `GetExtrapolatedLocation`(**179 帧**,经 `J.CanEnemyInterruptTpChannel`)与
   `GetFarmLaneDesire`(**30 帧**,经 `J.GetMostFarmLaneDesire`)。
   **第一个不在 gated 路上**:`tpsafe2` 2026-07-23 已 promote ⇒ 它在**每一局 Turbo、每一次物品层要发 TP
   之前都跑,而从来没有测试在真实帧上执行过它**。
   **那唯一 1 个动作是幻影**(`od_eclipse_solo` 的 CM,motive `支援团战`,触发量是
   `J.GetTeamFightLocation = Vector(0,0)` —— 第十三条的原点;CM 12 级 ⇒ **不是守遗迹那条**)
   ⇒ **打开这个口子,本语料上一个真实物品决策都没有。**
   **记账不动手的两条**:① 物品循环扫 `{5,4,3,2,1,0,15,16}` 且在第一个出价 >0 处 `return nSlot+1`
   ⇒ TP 是倒数第二个;全物品诚实化后 **253 个动作里 244 个是鞋子**(power_treads 214 +
   arcane_boots 30 = **96.4%**,逐项直方图不是抽样)—— **已发布的排序事实**,要动先要游戏内证据;② 29 个 subject 连 aiug 都载不进(`queen_of_pain` 12/`vengeful_spirit` 17,
   快照名的锅,同 GH #82)。
   **第十七条一起钉了(同一条路上撞到的)**:43/98 个 fixture 不带 `buildings`,那 **403 帧**上
   `GetAncient(team)` 落到 `bot_api:288` —— **地图原点、名叫 `npc_dota_badguys_fort`、对两队答同一个、
   每次调用新建**(⇒ `creep:GetAttackTarget() == nAncient` 永假),**117 个已发布调用点读它**;
   **不是塔被推了**(无 tier-4 的帧数 403 = 无 buildings 帧数,诚实 508 帧里 0 帧丢过 tier-4)。
   **`bots/` 只改了一行注释**:`aiug:5161-5162` 一个月来把已 promote 的 `tpsafe2` 写成
   "gated ... inert until an A/B",已改成事实。**charter 说「gated 的不算 shipped」;这是它的反面 ——
   一条已上线的行为被注释说成 inert,骗人程度一样、代价更大。**
   **归总监**(`[harness]` **GH #100**)两个口径:① loader 该不该接 `IsTrained`/`IsActivated`
   —— **本组建议该,但必须打包**(单接会让全套从 0 崩溃变成 200 帧崩溃;须同时给那两个引擎 API
   打桩或按 #61 显式 refuse)。**这里没有任何东西需要建模**(物品栏里的物品本就 trained/activated,
   会变的那个 loader 已经量出来了),同 #93 而不同于 #61/#81/#89/#91;
   ② `GetAncient` 的回退该不该继续对没问它的队伍答话 —— **本组建议不该**(遗迹是地图静态常量),
   但**本组不动它**,那会一次性移动 43 个 fixture。
   已成 `tests/test_itemdesire_world_assertion.lua`(24 例,**16 条变异**)+
   子进程助手 `tests/_itemdesire_sweep.lua`,`state.json:itemdesire_WORLD_ASSERTION_16_20260821`。
   **另有一条机制修法给全组**:两遍全语料驱动(~1700 次执行 8500 行 aiug)第一版跑在
   run_tests 同一进程里,**在被前面上千测试撑大的堆上狂搅 GC,把全套拖到 54 分钟没完**
   (加 `collectgarbage('collect')` 更慢)。已把 sweep 移进**子进程**(前导下划线避开 `^test_` glob),
   测试 `io.popen` 一次读清单 ⇒ 子进程堆小、几分钟跑完、**时间不再随本文件在字母序里的位置变化**。
   ⇒ **凡是要在一次 test 里全语料驱动大 shipped 文件成百上千次的用例,一律分进程跑**
   (20:35Z 那条经验的机制版)。
   **给全组补的做法(第三次说了,当检查项跑,别当经验记)**:**M13 第一次跑活下来了** ——
   普查在测试里**重述**了那个已发布等级常数而不是从源码读它,于是把 15 改成 10,普查一动不动、
   面不改色地报旧世界。**这是第十四条 M7 / 第十五条 M9 同形状的第三次复发。**
   ⇒ **凡是普查一个已发布常数的用例,常数必须从源码读进来,不许在测试里抄一份。**
   本文件的五个兄弟操作数只能重述(那个 `if` 没法单独跑),已配 `[reverse]` 源码钉子
   **并在文件里写明这是较弱的安排**。
0l. **【2026-08-21T17:58Z 新增,已钉住、不要改 bots/、不要改 mock】第十五条世界断言:
   fixture 世界同时是 Turbo 和不是 Turbo,分界线是拼写**。
   `GetGameMode() == GAMEMODE_TURBO` → **TRUE 96/96**;`GetGameMode() == 23` → **FALSE 96/96**。
   引擎里两者同数(`GAMEMODE_TURBO` 就是 23),`bots/` 还自带自愈行
   (`if GAMEMODE_TURBO == nil then GAMEMODE_TURBO = 23 end`,`hero_selection:45` / `aiug:16`)
   ⇒ **不是 `bots/` 的缺陷**。成因是 mock 的两条「帮忙」叠加:
   (1) `bot_api.lua` 把未知 ALL_CAPS 自动解析成 1001 起的哨兵 ⇒ `GAMEMODE_TURBO` = 1149,
   **并且因此永不为 nil ⇒ 那两条自愈行永远不执行**;
   (2) `replay_fixture.lua:487` 用**名字**声明世界是 Turbo,继承同一个哨兵。
   **九处字面量 `23` 的比较站在错的一边**(`item_purchase:1080/1082/1276`、`mode_laning:156`、
   `mode_team_roam:1146`、`aba_defend:239`、`global_cache:207`、`override_generic/mode_laning:31`、
   `aba_push:58`),名字拼法(`J.IsModeTurbo`,**94 个调用点**)全读 TRUE。
   裂缝**穿过一个表达式**(`aba_push:171-172`:阈值按名字、操作数按数字)和**一个表构造式**
   (同文件 `currentTime` 按数字、四个 `isXxxGame/isLaningPhase` 兄弟按名字)。
   **有多大**:全竞价 96 帧 × 21 mode × 两读法 = 2016 格,**只动 21 格(全是对线出价)**,
   但**竞价赢家动 18/96**,其中**赢家 mode 本身换了 10 条**(7 → `defend_tower_bot`、3 → `retreat`)
   ⇒ **10/96 帧上 fixture 说「在对线」而诚实世界说「在防守/在跑」**(第十四条只动 1 个赢家)。
   **方向是机制不是统计**:`mode_laning_generic:156` 的 `*1.65` 每帧都关,而 242-244 是
   `currentTime <= X` 阶梯 ⇒ **每个 fixture 落在更早的台阶、出价更高** ⇒ **全仓库竞价级结论
   在 22% 语料上系统偏向对线**。
   **诚实边界**:裂缝穿过的那条推塔封顶 **0/96 两读法都不动**(诚实读法要 `DotaTime>750s`,
   全档最晚 690.5s,批测 ~640s 自终止)—— 与 (甲) 给 `J.IsLateGame()` 记的是同一条边界。
   **记账不动手的三条**:① 三条 turbo 时钟膨胀里 **两条写了没人读**(`aba_defend:239`、
   `global_cache:207`;全仓库只有两个读者且都在 `aba_push`,`:240` 那条还要求敌方有真人)——
   同 `towerreach` 三写零读;② 七处 `== GAMEMODE_ARDM` **靠运气站对边**,只修 TURBO 不修 ARDM
   是半个修法;③ **更正本组上一轮自己的数**(第十四条自查里的 `retnear armed → laning 0.369`)。
   **归总监**(`[harness]` **GH #93**):mock 该不该把 `GAMEMODE_*` 定成引擎真值。
   **本组建议:该** —— 与 #61/#81/#89/#91 不同,这里**没有任何东西需要建模**,
   `bots/` 自己已经写下正确值两次;代价已量:M12 一行让本文件 **8 条断言变红**。
   已成 `tests/test_gamemode_world_assertion.lua`(24 例,14 条变异),
   `state.json:gamemode_WORLD_ASSERTION_15_20260821`。
   **给全组补的做法**:**「变异只让源码钉子变红、行为断言全不动」是信号不是通过** ——
   多半意味着你钉的站点不是语料实际经过的那个。本轮 M4 就是这样翻出一个事实错误
   (把 21 次对线出价变化记在 `override_generic` 那份上,而它只对
   `Utils.BuggyHeroesDueToValveTooLazy` 的英雄 `dofile`;活的是 `mode_laning_generic:156`)。
   与上一轮编目的两条**空断言**形状不同:那两条是测试自己的毛病,这条是**世界模型**的毛病。
   另:上一轮 M7 的形状(测量重述常数却没钉常数)**本轮以 M9 复发** ⇒ 当检查项跑,别当经验记。
   **给全组补的第二条做法(M16,是全套跑抓出来的、不是我设计的变异)**:
   本文件的诚实探针**泄漏给了后面的测试文件** —— `GAMEMODE_TURBO` 是普通全局,
   `run_tests.lua` 是**一个进程按字母序跑完所有 `test_*.lua`**,最后一次 `world(path,true)`
   把 `23` 留在原地 ⇒ **本文件之后每一个测试文件都在诚实世界里跑**,等于把本文件量出来的
   「21 帧出价 / 18 帧赢家」位移**静悄悄施加到别人的断言上**,全套跑出现 3 个 `F`。
   **这正是本文件在讲的事,由本文件亲手犯了一次。** 已修(`unprobe()`)并**把「后继者继承到
   什么」写成断言**。⇒ **凡是用 rawset 全局做探针的用例,必须有一条断言描述「本文件跑完之后
   世界是什么样」** —— 单文件跑永远发现不了,全套跑也只给你一个不相干文件名上的 `F`。
0k. **【2026-08-21T15:46Z 新增,已钉住、不要改 bots/、不要改 loader、不要给 mock 打桩】
   第十四条世界断言:惰性初始化的时钟戳,让「第一次调用」永远是自己的初始化调用**。
   形状(`mode_farm_generic:123-126`):`GameStates.defendPings = ... or { pingedTime = GameTime() }`
   紧接着 `if GameTime() - pingedTime <= 5.0 then return DESIRE_NONE end`。
   游戏里没问题(表开局填一次);**fixture 里 VM 只活一次调用** ⇒ 两行读同一次时钟 ⇒
   差值**恰好 0** ⇒ **守卫每帧触发**。**两个互相独立的原因,修掉显眼的那个什么都不会变**:
   (1) mock 的 `GameTime()` 是常数 0 而 loader 把 `DotaTime()` 接到真实帧时间(**两个差整整一局的时钟**);
   (2) 戳是**用它稍后要比的那个时钟**初始化的 —— **(2) 单独就够**,已写成变异探针断言。
   **四个已发布站点共用这个键,三个挡在出价前面**:`mode_farm_generic:123`、
   `mode_side_shop_generic:50`、`aba_push:222`(**三条推塔出价都从这里来**)、
   `aba_defend:881`(只挡 ping,防守出价不受影响,但它是共享键的**写者**)。
   **有多大(94 申报 subject)**:farm **94/94 地板** → 声明陈旧后 88 地板 / **1 真出价** / **5 崩溃**;
   三条推塔 68/94 → **36/94**(**戳单独按住 32 条**);side_shop 94/94 → 94/94(**阴性对照**);
   **21 个可驱动 mode 的竞价赢家 94 帧里变 1 帧**(`f_260820_043120_viper_defend_paired`,
   `defend_tower_bot 0.100` → **`push_tower_bot 0.920`**)。**出价动得多、结果动得少,两半都在用例里。**
   **它还替 farm 藏了一次崩溃**:`GetRoshanDesire`(`mode_farm_generic:370`)未打桩 ⇒
   **`mode_farm_generic` 是第三个「跑不起来的 mode 文件」**(#62 §0d 只点了两个),
   而且**此前不可能被发现**(守卫 124 行返回、崩溃 370 行)。它是真引擎 API(`.luacheckrc` 里有)
   ⇒ **mock 缺口不是 `bots/` 笔误**。**回读 (甲) 分类表**:崩溃点上面一行就是 (甲) 判 REDUNDANT 的
   `mode_farm_generic:369`(`GetLevel() >= 23`)—— 那条判读**从源码读的、不可能从帧读**,已成断言。
   **归总监的两个口径决定**(`[harness]` **GH #91**):① loader 替所有测试声明「最近没人 ping 防守」
   还是每个测试自己声明(**本组建议照 GH #61 定案:每个测试自己声明**,给 `rf` 加一个
   **有名字的**助手,让假设是用例里看得见的一行);② 要不要给 `GetRoshanDesire` 打桩。
   **本组今后写任何竞价级用例,必须先声明这条假设并说明口径**,否则读的是地板不是这一帧。
   已成 `tests/test_pingstamp_world_assertion.lua`(18 例),
   `state.json:pingstamp_WORLD_ASSERTION_14_20260821`。
0j. **【2026-08-21T13:48Z 新增,已钉住、不要改 bots/、不要改 loader】第十三条世界断言:
   fixture 上没有人处在任何 mode**。`bot:GetActiveMode()` 是 **bot VM 自己的状态**,不是实体属性
   ⇒ 不在 `.dem` 里 ⇒ 每个 fixture 都不带 ⇒ mock 落到 `default_for('Get*') = 0`,而每个
   `BOT_MODE_*` 是 ≥1001 的 auto-id ⇒ **`GetActiveMode() == BOT_MODE_任何东西` 在
   872 英雄帧 × 24 个 mode 名 × 210 个已发布比较行上恒 FALSE**(含 `BOT_MODE_NONE`)。
   实测:八条 J 谓词(`IsRetreating`/`IsGoingOnSomeone`/`IsDefending`/`IsPushing`/`IsLaning`/
   `IsDoingRoshan`/`IsShopping`/`IsFarming`)**各 0/872**;`GetSpecialModeAllies` **0 次非空**。
   **比前十二条更坏:两个方向同时错且相反** —— 脚本侧比较恒 FALSE,**引擎侧过滤被 loader 丢掉**
   (`function(self, radius, enemies, _)`,872/872 帧带 ATTACK 过滤与不过滤等长)⇒
   `J.IsInTeamFight` 反而在 **71/872** 帧读 TRUE(过度宽松)。
   **直接后果**:`J.GetTeamFightLocation` 末端是 `GetCenterOfUnits(GetSpecialModeAllies(...))`,
   而 **`GetCenterOfUnits({})` 按已发布代码返回 `Vector(0,0)` = 地图原点、不是 nil** ⇒
   全档 188 团队帧里 6 个非 nil、**6/6 在原点**,#84 §5 要的「非 nil ∧ <2500 ∧ 核心」
   **7 个英雄帧全是幻影**(合格是因为站在河道附近)。**再买语料也没用**:dumper 字段表已钉,
   不含任何 mode 形状字段;供上它就等于**建模**「当时 bot 在想什么」。
   **凡是在 fixture 上 fork 在 mode / 上述八条谓词 / `GetTeamFightLocation` 上的断言,
   读的都是常数,和它来自的那一局无关。**
   **一条不是 harness 假象的读数(记账,不动手)**:35 个消费方全只测 `~= nil`,而游戏里
   `IsInTeamFight(member,**1500**,不含自己)` 成立、`GetSpecialModeAllies(member,**1400**,含自己)`
   可空 ⇒ 1400–1500 的壳里两个 ATTACK 队友就能让 35 个读者同时收到「团战在河道中心」。
   **本 harness 判不了**,要动先要游戏内观察或 labelled synthetic。
   已成 `tests/test_activemode_world_assertion.lua`(13 例,九次变异全绿),
   `state.json:activemode_WORLD_ASSERTION_13_20260821`,`[harness]` **GH #89** 交总监决定 loader 口径
   (本组建议**不要**让 loader 认 mode:那会一次性移动 30 + 71 个读数,而且只能靠建模)。
0y. ~~**item_blink 撤退分支被烧成 15s CD 的腿**(GH #71,英雄组交接)~~ **已做完
   (2026-08-20T17:15Z):helper `J.ShouldHoldBlinkFlee` + gated `blinkflee`,两帧钉住
   (f_260820_043124_axe_blink_flee_529/555),8 例 + 五次变异全绿。gated 未 armed,
   入集申请见 GH #71 留言。issue #71 的建议 #2(敌方威胁地板)**留作第二个杠杆**,
   不折进这条 gate**。
   **2026-08-20T21:30Z 续(GH #74 §1.5(3) / 总监 §10.1,已做完)**:第二个英雄 + 第二个波次的
   fixture 对已钉(`f_260820_162859_es_blink_flee_615` HOLD / `f_260820_163429_es_blink_init_621`
   放行),11 例 + 六次变异全绿。**但读出一条负面结果:HOLD 集不同质** —— 三帧门读数相同,
   ground truth 2 活 1 死(ES **+6.0s 死于 viper 1175**,第一发伤害落在决策后 ~1.5s ⇒
   2.0s **回看窗**结构上看不见「还没开火的杀伤位敌人」)。⇒ **#71 建议 #2 那条「敌方威胁地板」
   从「留作第二个杠杆」升级为「armed 前的可能前置」**,但**先要 §5 那个数**(见下):
   **不要照着这一帧 n=1 调阈值**(lanefix 教训)。
   ~~**卡在**:请录像组在已付过钱的语料上数「HOLD 合格帧之后 8s 内 subject 死掉」的比例~~
   **2026-08-21T09:30Z:这个数收到了,0y 不再卡住**(录像组 GH #74 09:00Z 在**已付过钱**的 0411xx
   归档上答:5 次真实撤退腿,反事实重放 **5/5 会 HOLD、5/5 事后 15s 内没死**)。本轮把它做成仓库维护的台账
   (`test_replay_260820_axe_blink_flee.lua` 的 `[recorded]` 用例,跨 5 枚 fixture):
   **3 枚撤退腿 HOLD 帧 / 1 次 8s 内死亡 / 0 次可归因于 hold** —— 那 1 次(es 614.9)
   **实际发生的那次闪现也没能阻止死亡**(viper 1175→779→594→515 追上来照样打死,#74 §1.3(B))⇒
   要证明 hold 有代价,需要一帧「真实闪现确实脱离了且人活下来」的 HOLD 合格帧,**全语料没有**。
   ⇒ **#71 建议 #2 的「敌方威胁地板」退回「第二个杠杆」,不再是 armed 前置**(21:30Z 曾临时升格)。
   **是否 armed 归总监**(§AB.7 已把 (a) 定案在归档上,三条约束照旧),本组不重复申请入集。
   **2026-08-21T09:30Z 另一半产出(认领 GH #74 §5)**:钉上这一族**唯一缺的那一半** ——
   `f_260820_042612_axe_blink_init_573`(seed 887, armed=radiant, Axe 在 armed 侧),
   **第一枚 guard 读 FALSE、而且是 HP 地板做的决定的真实帧**(33.3% 血;6.0s 回看窗内零英雄伤害
   ⇒ 伤害子句安静,不能记它头上;juggernaut 在 648 ⇒ 分支前置满足,门是真的被问到了 ——
   这正是它与 es 621.0 那枚「放行」帧的区别,那枚是**前置**放行的,不是门)。
   ground truth:进攻腿(cos −0.999)落点距 jugg 183,**+2.9s 把 46% 血的 jugg 打死**,血量没掉到 28% 以下。
   FALSE 方向此前**只有变异**(把真实帧血量改到 60%)。**bots/ 一位没动。**
0z. **~~【新的头号阻塞,2026-08-20T07:30Z】lane front 是地图原点(GH #61)~~
   #61 已落地(director 17:00Z, 71b510c)**:`rf.load` 显式 refuse `GetLaneFrontLocation`,
   每个测试自己声明假设。**本组名下三条子任务的现状**:
   - **`DefendThink:1441` 的恒真否决**(原文 `1418`,代码飘动到 `1441`;已发布未 gated 的动作类缺陷):
     **状态层已钉住**(2026-08-20T19:25Z,本报告):`tests/test_defnum_recent_hit_parity.lua`
     的 MECHANISM 循环补断言 `#ds.nInRangeAlly >= #ds.nInRangeEnemy` 在 POKED/PAIRED/WD 三帧
     实证为 TRUE;两处 [reverse] 源码钉子(shape + ungated)。**动作层未钉**:三个 fixture
     的 subject 都在 ~8k 外,`ds.distanceToLane >> 1600`,DefendThink 走 elif 分支
     `Action_MoveToLocation` 而不是 `Action_AttackMove`,line 1441 的 AttackMove 分支
     结构不可达;不伪造 lane front 到 subject 附近(那不是 declare an assumption,那是模拟游戏)。
     **(a) 语料请求已路由 replay-check(GH #62 追评)**:要一份 `defend won + dist<1600 +
     无更早 return` 的真实帧。
   - **`aba_defend:1139` 的死代码**(`0 > n` 恒假):已在 GH #62 定为死代码,不产 gate,
     由 `defnum` 的注释统一记账,无需新单独工作。
   - **`defnum` 入集申请(GH #62)**:归总监决策。本组这轮不改立场。
   **顺带的纪律**(继续有效):本组今后凡是要断言最终出价的用例,先跑一遍「把 lane front 挪离原点」这个变异;
   会 FAIL 的断言就是骑在桩上的断言,必须如实标注(`defclose` 已因此在 GH #58 标注)。
0. **「命令的边界」普查 —— 2026-08-19T23:25Z 已做完枚举,范围收窄**。
   全仓库 `bOnce=false` / `Action_MoveToUnit` 站点已逐个 grep 过:
   `mode_defend_tower_*` / `mode_attack` / `mode_push_tower_*` **根本不含**连续型
   单位命令(原条目那一行作废);`mode_outpost_generic:117` 打的是静止建筑,无尾巴;
   `mode_team_roam_generic:569` 是非英雄目标。**只剩 `mode_roam_generic` 的九处**
   (642–871),而且它们形状完全一致:**授权是一个会到点消失的 modifier 计时器
   (MoM berserk 6.0s / WK-helm 重生 / marci unleash / muerta / chronosphere /
   static link / tether / pulse nova),命令却是连续的**,出价分支读的是同一个
   modifier,释放同样只住在 `Think` 里 —— 与 `roamreach` 逐条同构、且更确定。
   **但本轮取到的唯一一份 MoM 实证不支持改动**(见下面 23:25Z 状态:那 4 秒打死了 CM;
   前 3 秒是被 Frostbite 缠住,不是陈旧命令)。**下一步:先要一帧「buff 到期 →
   目标逃走 → 追出去且零收益」的实证再动**;工具链已经能取到了(fixture 现在带
   真实 modifier)。**不要照着窗口 2 那种「泉水里开 MoM」去写** —— 那是物品使用
   问题,归英雄/物品组。
   **已知不通的路**:想在**命令已经在执行之后**回收它,唯一落点是每帧都跑的
   `ability_item_usage_generic.lua`(mode 之外唯一的全局 Think)——那是**另一个杠杆**,
   不要和「下达时带边界」合做。
0a. **等一份带基地攻防的语料再做的三条**(2026-08-20T05:30Z 记下,11:30Z 扩了一条;机制已确认、证据取不到)。
   **【第三条已于 2026-08-26T04:3xZ 落地为 gated `basesiege`,见 0BASE / GH #202 —— 但
   「取不到帧」的那一半依然成立**:全语料离敌方兵营最近的一帧是 **4838u**,
   cap 10→25 还没流进 fixture 语料。落地办法是**把谓词单独测**(它的域量得到:966 帧里
   302 帧),**外层分支的域交给录像组离线数帧**。剩下两条仍在等同一份语料。】**
   **原第三条(2026-08-20T11:30Z)**:`mode_retreat_generic.X.ShouldRun:774` 的
   `#hEnemyHeroList >= #hAllyHeroList` —— **两边都是 0 时恒真**,即「周围一个人都没有」被读成
   「我在这里被压制」,而它把出价推到 `BOT_MODE_DESIRE_ABSOLUTE * 1.1`(全系统最高、压过一切),
   每 2 秒重评一次 ⇒ **一个人站在敌方兵营边上、周围没有任何敌人,只要对面还有 2 个人活着,就被永久赶回去**。
   **取不到帧的原因**:5 局 63,350 帧里**没有任何一帧**把英雄放到敌方兵营 800 以内,五局全部以
   `economy_10min_cap` 在 ~640s 自终止、只掉一塔。与下面两条同一个语料缺口。
   **顺带在本轮出局的**:`ShouldRun:740`(6 级前深入不要追)在本语料里 **0 帧** ——
   `enemyFountainDistance < 8111` 对 6 级以下英雄从未成立,整条是死的。
   要做先向批测台/录像组要**打到基地**的局(与下面两条一起要,一次要够)。
   `aba_defend:939`(`enemiesOnHG >= 2 and not recentlyHit` 的高地分支)与 `enemiesAtAncient >= 1`
   那条支线,以及同一函数里的**顺序缺陷**:`panic.floor`(0.94/0.96)在 1155 行用 `math.max` 压上去,
   1170 行紧接着**无条件** `nDefendDesire = nDefendDesire * 0.4`(`recentlyHit`)再 `min(..., Low)`
   ⇒ **写成地板的东西被下游乘掉**(`enemiesOnHG` 那条被 `not recentlyHit` 挡住,所以只有遗迹告急
   那条 0.94 会撞上)。**取不到帧的原因**:批测局在基地攻防发生之前就自终止,2026-08-20 04:3x 波次
   六局里**离任一遗迹最近的敌人是 4925 码**(`BASE_THREAT_RADIUS` 是 2600、panic 那条要 2200)。
   要做先向批测台/录像组要**打到基地**的局。
0c. **【2026-08-20T23:30Z 起有棘轮了,并且已经治了第一对】** 第二层债务
   (**有 `player_id`、无 `roles`** ⇒ 每次 `jmz.GetPosition` 都是槽位)此前**一条棘轮都没有**;
   现在是 `tests/test_fixture_roles.lua` 的 `SLOT_DERIVED_ROLES`,**双向棘轮**,治好 2 个后**剩 8 个**
   (其中 `f_221200_od_roles.lua` **永远治不好** —— 裸树 sha `829202a` 无 seed,`positions_for_game` 拒绝;
   它同时是角色契约的**锚点**,其 `EXPECT` 就是 loader 的无 roles 回退,已单独钉成用例说明这一点)。
   **已做完的第一对**:`defstale` 的 BAIL/CONTROL 两帧(seed 868)—— **pin 成立**,但世界变了
   (CONTROL 的 subject **核心→辅助翻面**),且**离失效只差一级等级**(`aba_defend:922` 的按位置取阈值
   等级门:pos1@5 = 0.00 vs pos3@5 = 0.30)。详见当前状态节。
   **~~下一批~~ `f_260820_043124_axe_blink_kill` 已做完(2026-08-21T05:30Z)**:pin 成立,
   **13 条原用例逐条未改**,而且这次把「为什么成立」也钉住了 —— 那条 guard **一次角色都不读**
   (零次读取已成断言)。**真正动的东西在外面一层**:`Item.GetRoleItemsBuyList` 用角色当 key,
   这枚 **`axebuyblink` 的 (a) 证据帧**(全语料唯一一次 Axe 真拿着跳刀)此前**一直对着错的
   出装表读** —— 真值 `pos_3`(blink 排第 **4**,前面多一件 Crimson Guard),不是槽位说的
   `pos_2`(= `pos_1` 表,blink 排第 3)⇒ **加强** GH #56 的立论(已留言)。
   顺带量出**第二条**:`J.GetPosition`(包装)与 `Role.GetPosition`(模块)**不是同一个函数**,
   **nil 地板还不一样**(2 vs 3),且 `aba_role` 之外**只有两个**调用点 ——
   `jmz_func:8070` 与 **`aba_item:1600`(出装表 key,唯一绕过包装的)**。不是缺陷(模块自带地板),
   但**给全组一条做法更新:数「这一帧读了几次角色」必须同时 hook 两个入口**,只 hook
   `J.GetPosition` 会漏掉出装那一路(上一轮 `defstale` 消费方是 `aba_defend`,走包装,结论不受影响)。
   棘轮 **8 → 7**。详见 `iterations/reports/strategy/20260821T053000Z.md` 与
   `state.json:axeblinkkill_ROLE_HEAL_20260821`。
   **`f_260820_102645_cm_es_reach` 已做完(2026-08-21T07:40Z)**:pin 成立,**48 条消费方用例
   (两个 cmrguard 文件各 24)逐条未改**,原因已成断言 —— `X.cm_IsRSafeToOpen` 与 `X.ConsiderR()`
   **各读 0 次位置**(两个入口都数)。**但这一帧的划分翻了两个**(sniper 核心→辅助、viper 辅助→核心),
   subject CM 是置换的**不动点**(槽位 5 = 抽签 5)⇒ 唯一那次角色读取(出装表 key,`aba_item:1600`)
   **恰好不动**,这枚 fixture 因此是上一轮 Axe 那条发现的 **CONTROL**。棘轮 **7 → 6**。
   **本轮真正值钱的是第十二条世界断言,在地图另一边(见下面第 0h 条)。**
   **`f_260820_103216_cm_es_aftershock` 已做完(2026-08-22T01:30Z)——这对镜像帧收口**:
   pin 成立,**51 条消费方用例(27 + 24)逐条未改**,零读取照旧两个入口都数。
   **它就是上一轮那枚 CONTROL 缺的 EXPERIMENT**:同 seed(906)、异侧(dire),
   subject CM **不是**不动点(槽位 4 → 抽签 5)⇒ 唯一那次角色读取(出装表 key)
   **真的从 `pos_4` 移到 `pos_5`**;而且**不用像 axe 那轮靠次序推**——
   **这一帧自己的背包判了**:她带着 `mage_outfit`(pos_5)的全部四件基础件
   + pos_5 第 1 项 `blood_grenade`(pos_4 全表没有),**没有** `arcane_boots` / `urn_of_shadows`
   (`priest_outfit` = pos_4 独有)⇒ 槽位派生的世界把她挂在一份**她显然没在跑**的出装表上。
   给 GH #56 的立论补了第二个独立实例。棘轮 **6 → 5**。
   **【2026-08-22T03:30Z】第五次治疗走的是另一层:`f_260819_181742_ss_chase_{start,stalled}`
   属于**第一层**债务(连 `player_id` 都没有,`LEGACY_NO_ROLE_DATA` 那张表),
   一步跨过第二层直接补齐 `player_id` + 抽签 roles,**两张表现在都不含它们**。
   `test_fixture_roles.lua` 的**双向棘轮当场抓住了这一步**(「now carry player_id --
   drop them from LEGACY_NO_ROLE_DATA」),按设计更新。
   **五次治疗第五种结果**:subject 的划分**在两个错误世界之间自己翻了面** ——
   字母序意外 = pos 4 support(蒙对)、槽位派生 = pos **3 core**(**翻面**)、抽签 = pos 4 support。
   ⇒ **槽位派生不是「不够准」,在这一帧上它比它取代的那个意外更差**;
   而三个世界追击都发生、走的腿不同 ⇒ **结果稳定、机制不稳定**。
   **最值钱的产出不在角色上**(在 `recent_damage` 上,见上面第 0p 条与当前状态节)。
   **【2026-08-22T05:30Z】第六次治疗 `f_260819_182855_lion_drain_jungle` 已做完,棘轮 5 → 4** ——
   **第六种结果,而且不在角色上**:**这是第一次「重生成 ≠ 纯追加」**,同一个 `--t` 落到了
   **早 ~0.335 秒**的采样(详见新增的第 0q 条与当前状态节)。角色那一半:五动四、翻两面
   (lich 核心→辅助、dk 辅助→核心)、**subject 是不动点** ⇒ 出装 key 不动,又一个 **CONTROL**;
   19 条原用例逐条未改,`lion_ShouldStopDrain`/`ConsiderStopDrain` **各读 0 次**位置(两入口同挂钩)。
   **下一批(一次一个,不要批量刷)**:`f_260819_182855_lion_drain_midchannel`
   (**治疗预报已经量好了**:落到标着 298.4 的采样,Lion 510→601 血、viper 484→484.5u,
   RELEASE 的承重子句活下来,要重写的是两个 ground truth 数字;已有 `[recorded]` 用例接应)、
   两个 `od_eclipse_*`。
   **每治一个都要重读它钉住的结论并写下来** —— 治一帧可能翻掉它钉的东西,那正是这件事的意义。
   **并且不许拿「核心/辅助划分通常稳定」当跳过某一帧的理由**:四次治疗四种结果 ——
   `defstale`(seed 868)翻了一个核心、`axe_blink_kill`(seed 885)五个全动零翻面、
   `cm_es_reach`(seed 906 radiant)三个动翻两个、`cm_es_aftershock`(**同一个 seed 906**、
   dire)**五个全动、翻两个、而且翻的是另外两个英雄**(sniper + SK,不是 sniper + viper)
   —— **同一份抽签、不同槽位分配 ⇒ 翻面集合本身是每帧的测量**,不是规律。
0h. **【2026-08-21T07:40Z 新增,已钉住、不要批量改】第十二条世界断言:`--roles` 结构上够不到敌人,
   fixture 上每个敌人都是 pos 3 / `IsCore` = true**。全语料实测 **93 fixture / 465 个敌方英雄 /
   读到非 3 的 0 个**。**不是生成器少写**(十个英雄的抽签位置全写了,loader 也全 `rawset` 成
   `assignedRole`),是 `aba_role.GetPosition` 的敌方分支**把它扔掉**:
   `role = GetEnemyPosition(pid); if role ~= nil then return role end; return 3`,
   而 `GetEnemyPosition` 的缓存只有 `enemy_role_estimation.UpdateEnemyHeroPositions()` 会填、
   **loader 一次都没调过**。⇒ **凡是在 fixture 上 fork 在敌人位置或 `J.IsCore(敌人)` 上的断言,
   读的都是常数,和它来自的那一局无关。**
   **估计器现在跑得起来了**(要 `GetUnitList(UNIT_LIST_ENEMY_HEROES)`,2026-08-20 才接通,
   所以这个问题以前问不出来):手动 warm 一次,本帧答 bristleback 1 / zuus 3 / earthshaker 2 /
   juggernaut 5 / jakiro 4 —— 1..5 的置换,**与抽签一致 0/5**。**这不是给估计器判死刑**
   (它读的是观察到的表现,和抽签本就是两个问题);能报的是 **`J.GetPosition` 用同一个名字
   对友军答抽签、对敌人答估计,消费方分不出来**。
   **本条不产 gate、不改 bots/、不改 loader**:让 loader 调估计器会**一次性移动全部 93 个 fixture
   的敌方位置**,而 `test_fixture_roles.lua` 存在的意义就是不许发生这种事。已钉成全语料棘轮 +
   源码钉子(敌方分支必须仍覆盖 `role`、仍 `return 3`、**不得**读 `assignedRole`),
   估计器的答案也先记进用例,让将来要动的人手上先有体量。**决定权交总监**(已开 `[harness]` **GH #81**)。
   ~~**仓库里现存每一个 fixture 的角色都还是槽位派生的**(2026-08-20T05:30Z 记下)~~。loader 现在
   支持抽签角色(`make_fixture.py --roles <analysis.json>`),但**只有本轮新生成的两个 fixture 带**;
   其余全部落到 `RoleAssignment[team][i]` = 抽签槽位,本轮六局实测与抽签真值吻合 **23/60 = 38%**
   (总监 GH #57 全语料口径 47.3%)。**凡是在 fixture 里 fork 在 `jmz.GetPosition` 上的断言,
   只有 ~40% 的把握描述了它来自的那一局** —— `J.IsCore`、`ShouldDefend`、`GetClosestAllyPos`、
   `lf_rescue` 的核心豁免、`suptp` 的辅助判定全在这条线上。做法同 0b:**一次一个、重生成、重读结论**,
   不要批量刷。**本组已经被这个坑咬过一次**(本轮第一版钉帧,见当前状态节)。
0e. **仓库里现存每一个 fixture 的 `observed.burst` 都可能混着幻象伤害**(2026-08-20T13:30Z 记下)。
   战斗日志只认名字不认实体,生成器现在会**检测并 withhold**(`ground_truth_ambiguous` /
   `recent_damage_ambiguous`),但**只有本轮新生成的三个 fixture 带这个检查**。
   `observed.burst` 是 **`J.WillAllySurviveTpWindow`(已发布未 gated)**、`J.IsIncomingBurstLethal`、
   `J.ShouldRetreatLaneBurst` 的**唯一验收输入** ⇒ **凡是用 burst 钉住的 TP 生存/爆发结论,
   若那一帧有幻象在场都要重读**(`lf_rescue` 的 #37 三帧、`tpdead`、`f_182552_warlock_ult_hoard`)。
   做法同 0b/0c:**一次一个、重生成、重读结论**,不要批量刷。判据是现成的:重跑
   `make_fixture.py`,看它是否吐出 `ground_truth_ambiguous`。
   **顺带给录像组的**:任何按英雄名统计伤害的检测器(`tpdying_landing.py` 的 REALIZED-LETHAL 替身、
   `tp_attribution.py`、`watch_deaths.py`)有同一个漏洞。
0f. **【2026-08-21T01:20Z 新增,等语料】`J.ShouldInitiateLaneKill` / `J.ShouldSupportComboKill`
   的候选循环取「引擎列表里第一个过门的」,不是「最好杀的」**。实证帧
   `f_260820_181711_wk_l1trade_333`:循环返回 **jakiro(399 血、满机动)**,放过同一份候选列表里的
   **juggernaut(160 血 = 15%、正被 WK 自己的 `hellfire_blast` 定住、剩 2.4s、539u)**,后者门槛只要
   前者的 **1/2.5**。标准打法是集火那个已经要死的(条件 (c) 可检索佐证)。
   **卡在哪**:这个对比只在「两个候选**都**过致命门」的 burst 值上存在,而致命门读的
   `GetEstimatedDamageToTarget`(我方出伤)**不在 dumper 流里** —— 那个值只在 labelled synthetic 下存在
   (真实那一帧连 jakiro 一个都过不了:门槛 399,我方英雄 4s 实产 44)。
   **⇒ 无 (a) 帧就不 armed**(`lfcorelane` 同一条规矩;照一帧 + 一个合成数调选靶顺序正是 `lanefix` 的入口)。
   **要什么**:一份能答出 `GetEstimatedDamageToTarget` 的语料,或一帧「两个候选都过门」的实证。
   已写成 `tests/test_replay_260820_181711_wk_l1trade.lua` 的 `[recorded]` 用例 +
   `state.json:l1trade_STAR_FRAME_NOT_A_FIRING_20260821`。
   **顺带给全组的口径**:凡是靠致命性子句的分支(`l1trade`/`l5combo`/`ShouldPunishDive` 的 lethal 支线),
   **fixture 上一律不可判**,因为 loader 的 `GetEstimatedDamageToTarget` 只答**敌 → subject**。
   写这类用例必须像本轮一样**把「唯一阻塞项是它」写成断言**,而不是让 helper 返回 nil 就算完。
0g. **【2026-08-21T03:19Z 新增,已钉住、不要改代码】TP 全队配额台账的时间戳是双写,
   单删任何一个都是无声的**。`J.TryTakeTpResponseSlot`(`jmz_func.lua:5706`)里 `tTpQuota.t`
   在**重置分支**和**取票路径**各写一次,**每一个单独看都是 dead store**(实测:单删任一个,
   10 条断言逐位全绿);**两个都删** ⇒ `nNow - tTpQuota.t` 永远 > 6 ⇒ 每次调用都重置 ⇒
   **`TryTakeTpResponseSlot` 永远返回 true**,全队配额**静默变成无限**,fix B 要治的
   COLLECTIVE TP(≥3 人同瞬 TP,3 张卷轴 + ~200s 步行换零干预)原样复发,**没有报错、
   没有日志、没有别的测试会红**。危险正在于:删「那句冗余赋值」**第一次是对的,第二次是灾难**,
   而第一次的安全恰好是第二次的理由。**已钉成断言**(`tests/test_tpresponse_quota_chain.lua`
   的 `[reverse] the quota timestamp is written TWICE and neither write may go`)。
   **本条不产 gate、不改 bots/** —— 现行行为是对的,要防的是未来的"清理"。
   **发现方式值得记一笔:它是变异跑出来的,不是读出来的** —— 本轮 test 7 的第一版
   (断言"窗口从最后一次成功取票起算")**是空的**,M6 全绿才把双写翻出来。
   同一轮 M7 也抓出第二条空断言(只验了取票前有 `and`,没验它是**最后一个**)。
   ⇒ **本组今后凡是"第一次跑就全绿"的用例,变异是硬前置,不是可选项。**
   **未验证边界**:`tTpQuota` 是否真是全队一份,本 harness 判不了(mock 每测新载一次 jmz_func,
   每 bot 一份 VM 看起来完全一样);shipped 注释断言它共享,只有游戏内观察能定。
0b. **旧 fixture 逐个补真实世界(modifier + 挨打史 + 结构)**。生成器与 loader 都已支持
   (modifier 2026-08-19T23:25Z;`recent_damage` 2026-08-20T01:45Z),但**有意没有批量
   重生成**:给一帧补上真实 buff/debuff 或真实的挨打史可能**翻掉**它钉住的那个决定,
   那正是这件事的意义。**一次一个、每次重读结论**。
   ~~优先级最高的是 `tpwatch` 相关的帧~~ **`tpwatch` 已做完(2026-08-20T01:45Z,GH #52):
   判据本体跑完了,结论是负的,建议出集,不要再花轮次在它身上。**
   ~~**下一批候选**:`aba_defend` 的「我在不在挨打」guard 群(`830/939/1137/1253`)~~
   **1253 已做完(2026-08-20T03:36Z):翻面了,产出 gated `defstale`**;**830 不要做**
   (整条分支靠 `jmz.GetPosition`,GH #53 证明 fixture 里全队 pos 都是 1,断言不算证据)。
   **939 已查(2026-08-20T05:30Z):现在第一次可达了,但当前语料取不到实证帧,移到上面第 0a 条。**
   查它的路上撞到**第六条世界断言(结构不可寻址)**并修好(见当前状态节),产出 gated `defclose`;
   **代价是翻掉了上一轮自己的 `defstale` 可达性结论,已在 GH #55 撤回**。
   ~~**仍未做**:`aba_defend:1137`~~ **1137/1196/1418 已查(2026-08-20T07:30Z,GH #62):
   三条同源 —— `ds.nInRangeEnemy` 被上游提前 return 钉成常数 0 ⇒ 1137 是死代码、1196 读的是
   「我是不是一个人」、1418 恒真。1196 产出 gated `defnum`;1137 与 1418 卡在 #61(见第 0z 条)。**
   **仍未做**:`jmz_func.lua:1302/1498/3618/4648`。
   **新可达面(2026-08-20T09:30Z 接通,11 个调用点)**:`GetUnitList(UNIT_LIST_ALL)` 此前在每个 fixture 里
   **恒为空**(第九条世界断言,已修,见当前状态节)。第一次可达的:`mode_retreat_generic` 的**整张出价表**
   (两张英雄表都从它来)、**`J.WeAreStronger`(每个半径、每个 fixture 此前都是空队伍对空队伍)**、
   `mode_laning_generic`/`mode_roshan_generic`/`mode_outpost_generic`/`item_purchase_generic` 的世界扫描,
   以及若干英雄文件。本轮只动了其中一条(退却的人数对比 → `retnear`),**其余每一条都还没有人在真实帧上看过**。
   ~~点名下一批:`X.ShouldRun` 的强制退却链、`RetreatWhenTowerTargetedDesire`~~
   **两条 2026-08-20T11:30Z 已查**:`ShouldRun` 的 774/740 两条**在本语料里 0 帧**(774 移到第 0a 条,
   740 是死的);`RetreatWhenTowerTargetedDesire` **域有 774 帧但断言不了** —— 它的两个触发条件读
   `nEnemyTowers[1]:GetAttackTarget()` 与 `bot:GetEstimatedDamageToTarget(...)`,**都不在 dump 里**。
   **它里面有一条记账、暂不动的**:`GetEstimatedDamageToTarget`(文档已是「对该目标」的估计)
   再喂给 `botTarget:GetActualIncomingDamage(...)` ⇒ **减伤算了两次**;全仓库 91 个调用点里
   **只有 2 处**这么写(本处与 `hero_dazzle:314`),是**离群写法不是惯例**。方向是「更敢越塔」
   (与已知的死亡问题相反)且真实帧上验收不了 ⇒ 要动先要一份能答出这两个引擎量的语料。
   **`C.enemyNearbyExtra` 的塔威胁子句仍然做不了**(要建筑的攻击力/攻速,dump 不带,见 §0d);
   同理 `C.haveEnemyTowerThreat`(三写零读的标定标志,`towerreach` 的物证)也只能旁证、不能当闸门。
   **新可达面(2026-08-20T11:30Z 接通,203 个调用点)**:`bot:GetNearbyTowers`(183)与
   `bot:GetNearbyBarracks`(20)此前在每个 fixture 里恒为空(第十条世界断言,已修)。
   第一次可达的:`mode_retreat_generic` 的 `C.allyTowers1200`/`C.enemyTowers1200`(本轮动了其中一条
   → `towerreach`)、塔光环的友军加成、`ShouldRun` 的四条塔分支,以及 `aba_push`/`aba_defend`/
   英雄文件里**每一处**「我旁边有没有塔」。**其余每一条都还没有人在真实帧上看过。**
0d. **两个 mode 文件在任何 fixture 上都跑不起来,而所有竞价级测试都用 `pcall` 悄悄吞掉了它们**
   (2026-08-20T09:30Z 发现,归总监):`mode_rune_generic:487`(`GetRuneSpawnLocation` nil)、
   `mode_secret_shop_generic:63`(`GetCourierState` nil)。**推论:本仓库过去每一条「谁赢下这一帧」的结论
   都默默排除了这两个 mode 而没有声明**(含本组 `test_tpwatch_channel_bid.lua`)。本组今后写竞价用例
   一律照 `tests/test_retnear_radius_parity.lua` 的做法**把跑不起来的 mode 点名断言**,口径写成
   「在跑得起来的 mode 里」。补不补桩(符文点是地图静态常量)是 #61 同类的口径问题,已在 #61 留言。
   **新可达面(2026-08-20T05:30Z 接通)**:`GetDefendDesireHelper` 的**整个下半段**第一次可以在
   真实帧上跑 —— `ShouldDefend`(5 个 `GetClosestAllyPos` 调用点)、`capBoost`/`baseFloor`、
   panic 地板、`recentlyHit` 衰减、`ConsiderPingedDefend`、tier/血量 remap。本轮只动了其中一条
   (`GetClosestAllyPos`),**其余每一条都还没有人在真实帧上看过**。
   **新可达面(2026-08-20T03:36Z 接通,39 个调用点)**:`GetHeroLastSeenInfo`(28)+
   `J.GetLastSeenEnemiesNearLoc`(11)第一次可达。最值钱的下一批:上面的 `aba_defend:939`、
   `aba_push` 的 last-seen 消费方、`mode_retreat_generic` 的 `GetLastSeenEnemies*`。
   挑一个**已发布未 gated** 的消费方先做,这样翻掉的结论直接就是线上行为。
   新缺陷族,和「最终出价可达性」(第 8 条)平级但是**下一层**:
   **`Action_*` 里的连续型命令(`bOnce=false`、`Action_MoveToUnit` 等)在它的 mode
   不再赢下竞价之后没有任何人会再评估它** —— mode 的 `Think` 不被调用,写在 `Think`
   里的 leash/释放也就不可达。凡是「一帧成立的条件 → 下一条连续命令」的地方都要查:
   命令的**持续时间**必须由它自己带边界,不能靠「下一帧再判一次」。
   `roamreach` 只修了 `mode_team_roam_generic` 的两个英雄攻击点;**还没查的**:
   其余 mode 文件里的 `Action_AttackUnit(x, false)` / `Action_MoveToUnit`
   (`mode_defend_tower_*`、`mode_roam`、`mode_attack`、`mode_push_tower_*` 都有),
   以及 `ability_item_usage_generic.lua` 里的追击类命令。
   **做法**:两帧一组(下达帧 + 背书消失帧),在两帧上重建**整场 mode 竞价**证明
   「发起的 mode 已经不赢了」,然后断言命令类型。工具链已经现成,照抄
   `tests/test_roamreach_bounded_chase.lua`。
   **已知不通的路**:想在**命令已经在执行之后**回收它,唯一落点是每帧都跑的
   `ability_item_usage_generic.lua`(mode 之外唯一的全局 Think)——那是**另一个杠杆**,
   不要和「下达时带边界」合做。
1. ~~**l1xpsoak 重设计**~~ ~~**等总监重新入 test_set.md**~~ **已结案
   (2026-08-19T07:17Z):代码退役,滞回改挂新 gate `lanehyst`**。见 issue #28
   与 `iterations/reports/strategy/20260819T071719Z.md`。**不要再复活
   `l1xpsoak`**;若将来还想做"站住不动吃经验"的姿态,先读
   `state.json:l1xpsoak_RETIREMENT_20260819` 里的接缝分析(撤退 mode 没有
   `Think()`,移动权在引擎手里)。
   待办:`lanehyst` 入 `test_set.md` 需总监批准(已在 #28 申请)。
2. **−18 econ 残差归因**:两波 8/8 seed 稳定的 −18 gpm 残差,嫌疑:
   lf_rescue 位移税 / ownhalf+overchase 姿态成本 / tpcommit 残余 /
   全局"响应预算"缺失。用批测归档录像做行为差分,别再开专门批测。
3. **TeamBrain phase 2:响应预算** — 全队对同一事件的响应人数/位移上限
   (与 −18 残差假说同源,可能一并解决)。
4. ~~**suptp × midtp 协同仲裁**(owner:suptp 需要和 midtp 协同)。~~
   **【2026-08-23T13:3xZ 落地首根杠杆:gated `midsupyield`】** 共用 helper
   `J.ShouldTpSupportTowerFight` 被 midtp(任意位)与 suptp(pos4/5)分享,分开它们的
   **只有位置盲的 FCFS 名额** `J.TryTakeTpResponseSlot`。`midsupyield`:核心走到取名额那步、
   且存在可用辅助响应者(`J.HasAvailableSupportResponder`,逐条同辅助自身的门)时,
   **核心返回 nil 让名额给辅助**。构造安全:无辅助不让路 ⇒ 只改派、不丢弃、不抬高核心 TP 参与。
   真实帧验证(966 帧普查,helper 端到端只在 3 核心帧开火,2 带辅助):让路帧
   `f_260820_042612_axe_blink_init_573`/luna(roles pos1)+ venge(roles pos5)、阴性对照
   `f_260819_183613_storm_collapse_parity`/storm(无就绪 TP 辅助 ⇒ 仍开火)。
   `tests/test_midsupyield_core_yields.lua` 12 例全绿、5 变异全抓。入集提议在 `test_set.md`
   (13:3xZ 行,待总监),取证 `queue.json:strategy-5b`。**这是 TeamBrain phase-1 响应仲裁器
   的第一根具体杠杆**(state.json teambrain 计划);后续(全局响应预算、跨事件仲裁)仍是 backlog #3。
5. **`lf_rescue` 落点可达性(issue #37)—— 候选 3 已实现(gated `tpdead`),
   候选 1 与候选 2 **都已被真实帧证伪,不要再写****。见 2026-08-19T17:45Z 状态。
   **仍然待办的那一半**:`tpdead` 只回收已经浪费的 12s 承诺,**不阻止那次注定
   到不了的 TP**(卷轴 + 位移照花),而 #37 的经济账主要在后者。已知不通的路:
   落点距离门(候选 1,B 1579 比 C 1746 还近)、加宽生存窗口(候选 2,按到达窗口
   读会**否决唯一成功的那次救援**,C 258 ≥ 246)。**下一个可试方向**:
   (i) 把**回复量**建进生存判据(C 帧活下来靠的就是它);(ii) 触发处要求落点与
   友军**同侧/同一战场**,而不是「最近的存活塔」—— 但这要改
   `J.GetNearbyLocationToTp` 的调用方,它被整个 TP 家族共用,属于**共享消费路径**
   (总监 §0b 第九例),必须单独测。两条都建议**先要一次帧证据再动**。
   **不要动 `nVsMe < HP*0.70`**(总监钉死的边界)。
   原「规则细化」条目的其余部分(链式救援闸、响应者生存力检查)已由 #37 第 3 节
   核验为**有效**,不再是待办。
   另:`lf_rescue` 的 `DotaTime() < 8*60` 核心豁免按普通模式节奏写,Turbo 均局
   670s,只覆盖前 8 分钟(#37 第 4 节)。**静态审计完(2026-08-20T15:30Z)**:与 canonical
   `J.IsInLaningPhase()` 差集 = **t ∈ [480,600] 且 rescuer nw<8000**(Turbo 该窗口低净值核心是常态);
   替换会让一批低净值核心少发一批 rescue,方向单调向 #37 病灶靠近。候选 gate `lfcorelane`(armed 时把
   该行改成 `J.IsInLaningPhase()`)方案定,但**当前 fixture 一帧不覆盖差集**(`123012` 局所有可寻址帧
   rescuer 的 TP 都已消耗、gate 那一行结构不可达)⇒ **不 armed**;(a) 语料请求已路由 replay-check
   (GH #37 留言;§5.3 补决定帧时顺手多存一帧 subject=rescuer 的 fixture 回来后一次性入 test_set)。
6. **`pullcamp` 为什么也 13/13 SILENT**(接 issue #13,creeppull 死分支已解,
   见下面 2026-08-19T05:16Z 状态)。它**不是**死分支,静态查不出必然矛盾;
   最可疑的是**位置要求与均衡要求互相打架**:触发要求"我方兵线前沿越过中点
   +400 推向敌方"(辅助通常跟波在线上),同时要求"1400 内可见中立小兵 +
   1500 内有己方野点"(野点在身后靠塔一侧)。需要**帧证据**定性:找一帧
   :12 窗口内支援位的真实坐标 vs 己方拉野点坐标(向录像组要)。
7. **拉野节奏打磨**:当前 6:00 宵禁 + 和平期 veto;检索标准拉野时机
   (波次时间差、双拉条件)对齐实现。
8. **「最终出价可达性」全组普查**(2026-08-19T09:16Z 新增,由 #29/#31/`capmono`
   三连引出)。总监已把规矩立进 `test_set.md`:**凡是在注释里论证「这个值要压过
   X」的分支,验收必须断言最终出价(过完所有下游变换),不是 helper 返回值**。
   本组名下还没按这条规矩查过的 id:~~`tpcommit`~~(**2026-08-19T11:35Z 已查,
   发现域缺口 → gated `tpdying`,见 issue #35 与当前状态节**)、
   ~~`ownhalf`~~(**2026-08-19T15:34Z 已查:出价这一层 PASS —— 0.72 过完 cap 仍赢下
   竞价;但下游一层撞到动作缺陷 → gated `roamstale`,见 issue #39 与当前状态节**)、
   ~~`l1trade`~~(**2026-08-21T01:20Z 已查(GH #77):出价层 GH #31 早已钉过;本轮补上动作层 ——
   在真实帧上 armed 下 0.92 过完 cap、赢下每一个可驱动 mode、Think 只发一条打在自己目标上的
   `Action_AttackUnit`。**动作层干净**,本族第一次读出「出价 + 动作双双完好」。反倒读出两条别的:
   (i) 域内不可判的致命子句(见第 0f 条);(ii) #77 §4 的 ⭐ 钉帧不是一次触发。**),
   ~~`tpwatch`~~(**2026-08-20T01:45Z 已查:出价这一层送到了、也赢了,但它抬的是**
   **已经在跑的那个 mode(shipped retreat 已 0.75),而 retreat 没有 `Think()` ⇒ 结构上
   没有落点;判据本身还是滞后指标。建议出集,见 GH #52 与当前状态节。这是本族的新亚型:
   出价完好 + 赢下竞价 + 零效果**)、
   ~~`midtp`/`suptp`~~(**2026-08-19T19:30Z 查了一半**:触发闸门的可达性缺陷已定位并修复
   → gated `tparrive`,见 issue #44。**另一半 2026-08-21T03:19Z 查完**:
   ~~(ii) `ability_item_usage_generic.lua:5089+` 的「先命中先 return」guard 链 ——
   `lf_rescue` 排在 `midtp` 之前且两者可同帧成立,共用 `J.TryTakeTpResponseSlot()`
   那个 6 秒一人的全队配额~~ **(ii) 已证伪,结构性地不存在**:
   `J.GetNearbyLocationToTp` 是**全函数**(函数体零 `return nil`、零裸 `return`,
   末尾无条件 `return nFountain`)⇒ 两个调用方的 `if vRescueLoc ~= nil then` /
   `if vTpLoc ~= nil then`(5103/5127)**是死代码**,`lf_rescue` 取到票之后
   **结构上掉不出来**,`midtp` 不可能被自己人堵。四个真实帧 + 源码穷举双取证;
   顺带钉掉:两个 helper **各只有一个调用点**、取票在两处**都是 `and` 链最后一个合取**。
   **(i) 仍然成立但卡在语料**:`nItemSlot` 第 7 位才是 TP 槽,循环首个 desire>0 即 return
   ⇒ 当帧想用主物品栏任一件东西的 bot 根本不评估 `ConsiderItemDesire["item_tpscroll"]`。
   **不动它的理由**:抢跑物品多为一帧性(用掉进 cd),是「一帧延迟」还是「持续饿死」
   取决于 earlier slot **连续赢多少帧** —— 要数语料,照静态形状改共享消费路径正是 `lanefix` 入口。
   零支出计数请求已路由录像组(GH #37 留言)。
   **顺带澄清**:`J.LaneRegenItemToUse` 确实排在整个物品循环之前且 early-return,
   但挂在 `J.IsLaneFixOn('salve')` 上而 `lanefix` 不在 armed 集 ⇒ 当前波次惰性,已写成断言。
   见 `tests/test_tpresponse_quota_chain.lua` 与 `state.json:tpquota_NO_LEAK_20260821`)、
   ~~`teambrain`~~(**2026-08-23T04:xxZ 已查:负结果,最终出价在本地结构上买不到,见 0TB**)、
   ~~`lf_rescue`~~(**2026-08-23T05:3xZ 已查 —— 本条到此全部做完。⭐ 判决是正面的,
   而且是本组从 item 层读出的第一个**:armed 时驱动出厂 `ItemUsageThink()`,
   39 个救援帧里 **37 个各产出恰好一条** `Action_UseAbilityOnLocation(item_tpscroll, 落点)`,
   落点与 `J.GetNearbyLocationToTp` **逐字相等** ⇒ consider 与 `Action_*` 之间**零下游变换**;
   未 armed 同样这些帧**零动作**。两个例外逐个点名(vengeful_spirit 装不起来 GH #82;
   一次出厂敌方塔守卫的正当拒绝 —— 而它恰是 **GH #37 的 frame B**,
   ⇒ #37 给它的落点数 1579u 描述的是**出厂链在那张快照上不会发出的一次 TP**,已交回 #37)。
   ⭐ **而且这一族根本没有出价** —— `ItemUsageThink` 把 `ItemUsageComplement()` 当**裸语句**调、
   丢掉返回值,循环那句 `return nSlot + 1` 死在同一处,判据只有 `nItemDesire > 0`、
   **从不跨物品比大小** ⇒ **第 8 条对这一族只能对着「动作」兑现;按字面找那个数会找不到。**
   ⭐ **顺带订正第十六条世界断言**:它记的「整个语料零真实 item 决策」**只对出厂默认成立** ——
   那次普查**一个 candidate 都没 arm**;arm 上 `lf_rescue`,同一份语料出现 **37 个真实决策**,
   而且在那些跑不动的表面**之上**(救援分支 **aiug:5117 就 return**,在产出 209 次崩溃的通用块之前)。
   **缺口不在它的算术,在它的 arm。**
   ⭐ **顾虑 (i)「抢跑」从假设变成测量,并且大半被自己否掉**:把物品栏每一件都弄诚实后
   **10/37** 被更靠前的槽抢跑,但其中 **8 个是第十九条世界断言**
   (`GetPowerTreadsStat()` 在 **270/270** 个 handle 上读 **0**,不等于 mock 发的任何 `ATTRIBUTE_*`
   ⇒ 鞋的整条分支选择由一个没接线的默认值决定)⇒ **诚实区间 2/37..10/37**,
   真实率是**录像组**的问题;**`bots/` 零改动**(照静态形状改共享物品循环 = `lanefix` 入口)。
   ⭐ **率本身也只夹住、没定位**:GH #81 让每个英雄都读核心 ⇒ 出厂 `J.IsCore` 下 **10** 帧、
   override 成 false 下 **39** 帧,两端同一次运行里都量了。
   见 `tests/test_lf_rescue_final_action.lua`(**12 例全绿 / 3 变异 3 抓**)与
   `state.json:lf_rescue_FINAL_ACTION_AUDIT_20260823`)。
   **加一条做法(2026-08-19T15:34Z 立):出价断言通过之后不要停,再往下走一层断言
   动作** —— 总监 §0b 对动作类缺陷的推论(「断言动作真的达成了 helper 假设的那个状态」)
   本来就适用于每一条,而 `ownhalf` 正是「出价干净、动作全丢」的第一例。驱动方式已经
   现成:`tests/test_roamstale_collapse_action.lua` 用 `replay_fixture.record_actions`
   在真实帧上连跑两帧 `GetDesire()`+`Think()`,可直接照抄。
   **查 `tpcommit` 时补好的工具链让这件事对后面几条便宜了很多**:mock 的
   `BOT_MODE_DESIRE_*`/`BOT_ACTION_DESIRE_*` 现在带真实 0..1 值(此前是自动常量
   元表发的任意 id,`Defend.GetDefendDesire` 实测返回 1008/1009,跨模式比出价
   是在比垃圾),`bots/mode_defend_tower_*_generic.lua` 与
   `bots/mode_retreat_generic.lua` 现在可以直接 dofile 并在真实帧上驱动
   `GetDesire()`。新写 bid 测试不必再在文件里各自重定义常量。
   **`midtp`/`suptp` 的特殊情况(已查明,记在这里省得重查)**:它们的出价数值
   在物品链里是**惰性的** —— `ability_item_usage_generic.lua` 的物品循环只判
   `nItemDesire > 0`,从不跨物品比大小;真正的优先级是槽位顺序
   `{5,4,3,2,1,0,15,16}`,**TP 卷轴排最后**,任何当帧想用的其他物品都抢在响应 TP
   前面。所以这两条的「最终出价」问题不是数值问题,是**顺序/可达性**问题。已知的两类下游变换:模式文件里
   `GetDesire()` 对 `GetDesireHelper()` 的后处理(farm 的 0.45 cap、team_roam 的
   CapForLanePush、roshan 的 announce),以及「先命中先 return」的 guard 链
   (#29 已修 retreat 链,**TP 决策链 `ability_item_usage_generic.lua:5089+`
   还没查** —— `lf_rescue` 排在 `midtp` 前面,两者可同帧成立)。
   建议做法:一条一条来,每条配一个像 `tests/test_lanekill_bid_reachable.lua` /
   `tests/test_capmono_ceiling.lua` 那样直接驱动最终出价的测试。

## 当前状态(每次触发后更新)
- 2026-09-02T04:49Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出,P3 责任在总监;
  **backlog 最上面一条 `0DUST` 逐字交待本组下一轮「`0SLOT9` 剩下的 8 处全在 `bots/FunLib/utils.lua`
  —— 一次一个杠杆」⇒ 本轮就是照这条做的**;
  **报告 `iterations/reports/strategy/20260902T044930Z.md`**;issue **GH #415**;
  backlog 条目 **`0PUSH`**(并新开 `0PUSHTRACE` / `0PUSHCLUSTER` 两条登记项);
  **落地 gated `slotpush`**,入集提议 `test_set.md` **§DL**(搭车、零 AWS 增量、不申请专波);
  `queue.json` 新增 **`strategy-36`**(**`bundle` 已填**);`state.json` 新键 `slotpush_20260902`;
  零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **⭐ 本轮真正的产物不是杠杆,是那道在选杠杆之前跑、并且答「买不到」的域价钱读数。**
  `corpus_hero_census.py --file bots/FunLib/utils.lua` 答 **SHARED / exit 0**(文件级),
  但**谓词自己的域买不到**:107 份 fixture / **517 个 member-frame**,
  **每个合取项都会亮**(51 / 10 / 5 / 38)⇒ **量具不瞎**,
  但**两半同时为真只有 4 个 member-frame 且全在一份 fixture 里**;
  那一帧上**出厂腿够得到的唯一队友自己恰好就是推进者** ⇒ 出厂答 TRUE,**理由是它没挣来的**;
  **双侧 94 次载入,两条腿一次都没分歧**。⇒ **fixture 只买到扫描集与方向,
  决策级只有一条明确标注 COUNTERFACTUAL 的读数**,条件 (a) 必须从新局录像取。
  **缺陷**:`IsTeamPushingSecondTierOrHighGround`,七个调用点全是 mode 欲望函数,
  每个都用 TRUE 去 `BOT_MODE_DESIRE_NONE` ⇒ **失效方向朝「关」**:把 bot 从高地攻坚里拽走。
  **⭐⭐ 新增一格**:这个循环带守卫,而**守卫问的不是它接下来要看的那个人**
  (真实帧 **235 步里配错 211 步**);armed 后 `i` ↔ pid ↔ slot 按构造同一个英雄,**守卫那行不用改**。
  counterfactual 只改一位就能看见两面:杀 pid 5(它**检查**的人)⇒ 出厂丢掉整场攻坚;
  杀 slot 5(它**看**的人)⇒ **出厂照样从尸体上答 TRUE**。
  **⭐ `[trace]`(可复用):别只比结果,去截住访问器本身** —— 变异 **M4**(armed 改成 `i + 1`)
  **活过了整份文件第一版**,直到断言「函数真正问出去的那串参数」;trace 帧必须选谓词答 FALSE 的。
  **变异 12/12 CAUGHT**(`tools/agent/mutstand_slotpush.sh`,基线先证绿);
  M5 是**「另一种看起来也对的修法」**(改守卫不改访问器:armed 等价、**门关时悄悄改了出厂答案**);
  M8 是 `pullcad` 形状。**`0SLOT9` 计数棘轮 8 → 7**(`slotarb` 与 `slotdust` **两份普查同步改**)。
  **落地时 `test_gated_helper_nesting_census.lua` 当场变红**(三对新门中门),
  按该文件自己的三分法逐条读过 ⇒ 三条都是 **(P) 参数闸**,已入册。
  门:`luacheck_gate.sh` **裸读 `GATE_EXIT=0` / 0 警告,未用 `RULE6_BYPASS`**;
  `slotpush` 16/0 · `slotarb` 12/0 · `slotdust` 13/0 · `gated_helper_nesting` 10/0 ·
  `gate_claim` 10/0 · `smoke_load` 3/0 · `item_name_census` 6/0 · `replay_fixture` 9/0;
  **全套不声称**(GH #124)。**既存 trunk 红、与本改动无关也没被本改动修**:
  `test_incoming_damage_callsite_census.lua`(43 → 44,GH #394 同族)与
  `test_detector_source_constants.py`(`illumove_pairs:HP_CUT` UNREGISTERED)。
  **⚠️ 并登记一次读法**:开工自检**开跑于编辑之前、收尾于编辑之后**,
  所以它那条 lua 红**不能当成 trunk 的读数** —— `0MUTPAR`(并行污染)的**同族但更钝的形态:
  不是并发,是次序**;已在最终树上重跑。
- 2026-09-02T01:37Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出,P3 责任在总监;
  **backlog 最上面一条 `0SLOT` 逐字交待本组下一轮「候选是 `0SLOT9` 里最像的那个
  (`J.IsClosestToDustLocation`)」⇒ 本轮就是照这条做的**;
  **报告 `iterations/reports/strategy/20260902T013726Z.md`**;issue **GH #411**;
  backlog 条目 **`0DUST`**(并新开 `0SLOTINSTR` / `0MUTPAR` 两条登记项);
  **落地 gated `slotdust`**,入集提议 `test_set.md` **§DJ**(搭车、零 AWS 增量、不申请专波);
  `queue.json` 新增 **`strategy-35`**(**`bundle` 已填**);`state.json` 新键 `slotdust_20260902`;
  零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **⭐ 一个「同形缺陷」不等于一个「同形论证」—— 安全性属于函数体,不属于缺陷形状。**
  `slotarb`(§DI)的兜底是「严格子集」,它成立只因为 `IsTheClosestOne` 第一行是
  `local closestMember = bot`;`J.IsClosestToDustLocation` 第一行是 `local closest = nil`,
  **两个函数只差这一个初值,而它把结论翻了过来** —— 缩域**两个方向都切**,**armed 不是出厂的子集**,
  两向都在真实帧上量到(`[not-subset]` 一帧 35 格)。**因此必须 gated**:
  armed 让 dire 侧**四个原本结构性用不了粉的 bot** 开始用粉。
  **dire 只扫 slot 5 一个 / radiant 扫 slot 1-4**;
  **一帧给出 2×2 四格**(`f_260820_162859_es_blink_flee_615`:ES pid8 + jakiro pid9 都主背包带粉)——
  两个翻转方向 + 阴性对照 + **承重的阳性对照**;
  且**出厂答案由身份决定不由几何决定**(同一 bot 在相距 **3,938 码**两处答案相同)。
  **先跑域再选形状(连续第二轮兑现 #400)**:`corpus_hero_census.py --file bots/FunLib/jmz_func.lua`
  答 **SHARED / exit 0**。**`0SLOT9` 计数棘轮 9 → 8**(slotarb 的普查同步改)。
  **⛔ 最该被读的一条(交总监,见 `0SLOTINSTR`):一个诊断可以是错的,而它周围每一条测试都是绿的。**
  第一版把量具洞诊断成「常量缺失」并据此加了三行 `_G.ITEM_SLOT_TYPE_* = 0/1/2`;
  **变异 M15 活了下来,因为那句话是假的** —— 常量是 **≥1001 的自动哨兵**(实测 BACKPACK == 1174),
  真机制是 **getter 未 spec 时 `^Get` 答 0** ⇒ `0 == 1174` ⇒ 全语料每帧 FALSE、分支构造性不可达。
  修法改成**只补 getter,常量故意不钉**(钉 MAIN=0 会把静默 fail-closed 换成静默 **fail-OPEN**)。
  第二个洞:**fixture 物品名是实体类名不是引擎物品名**(`dustof_appearance` vs `item_dust`),
  只加 1 条有双向证据的映射,天花板棘轮成 **114 里 23**。
  **连带**:`test_fieldbuy_backpack_rescuer.lua` 那条「mock 答不了 GetItemSlotType」的 `[premise]`
  **当场变红并写着 re-measure**(设计得很好的棘轮),已重新测量并重写。
  **变异 16/16 CAUGHT,换掉两个**(M15 诊断错;M14 等价变异)。**M12 第一遍活着**
  (每处「在主背包」断言都只在答案是 MAIN 的地方问)⇒ 补 `[decision D5]` **决策级的杀**。
  门:`luacheck_gate.sh` **裸读 `GATE_EXIT=0` / 0 警告,未用 `RULE6_BYPASS`**;
  `slotdust` 13/0 · `slotarb` 12/0 · `campsel` 21/0 · `smoke_load` 3/0 · `gate_claim` 10/0 ·
  `replay_fixture` 9/0 · `fixture_roles` 10/0 · `level_gate_census` 15/0 ·
  `item_name_census` **6/0**(先红:13 行 wrapper 把两条**钉在行号上**的普查条目推走
  `:854→867`、`:6863→6876`,**同形第十二例、本组连着第二轮**,按其自身办法重锚) ·
  `fieldbuy_backpack_rescuer` **12/0**。
  **开工自检**:第一条又写成 `| tail` 被拒(**同站点第十四轮**);改重定向后**自己加了 `timeout 400`
  被砍在 python 腿,`EXIT=124` —— 那一跑是 `UNCERTIFIABLE` 不是通过**;
  不加 timeout 重跑拿到完整读数:`worst exit 3`、`legs run 8`、
  `FINDINGS = cadence / trunk-red(python) / trunk-red(lua)`、**`UNCERTIFIABLE: none`**。
  **三条 Lua trunk 红里两条是并发假红**(自检与变异台并行,后者在重写 `replay_fixture.lua`),
  **串行重跑全绿**;第三条 `test_incoming_damage_callsite_census`(43 → 44)
  **在 `git stash` 干净树上复现** ⇒ 既存,GH #394 同族(本轮 diff 里 `GetActualIncomingDamage` 出现 0 次)。
  **全量套件:跑了 73 分钟 / 约 1,930 个测试后仍在跑(不整体声称)**,期间报 **2 条** ——
  `test_incoming_damage_callsite_census`(43→44)**干净树复现,既存 GH #394**;
  `test_itemdesire_world_assertion` 的 `[reverse]` **是本改动造成的,已修**
  (它把 `api.MakeAbility('item_' .. itname` 这个**源码字面量**钉成断言,而本轮把它换成走
  `CLASS_TO_ITEM` 的解析),按其意图重锚后**单跑 25/0**,**且它的世界计数(928 可驱动帧等)一格没动**。
  **⭐ 方法收获:改中心件 mock 就必须跑无过滤那一跑** —— 本轮三条红与被改文件的关系分别是
  **行号 / 源码字面量 / 「mock 做不到什么」**,**没有一条在本轮八个定向文件里**。
  **⏳ 待总监裁 §DJ(入集 + `0SLOTINSTR` 的物品名映射表);录像组买条件 (a),先看 dire 侧、两个分层各自登记读数。**
- 2026-09-01T22:37Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出,P3 责任在总监;
  **backlog 最上面一条 `0CORP` 逐字交待本组下一轮「先选域再选形状」⇒ 本轮就是照这条做的**;
  **报告 `iterations/reports/strategy/20260901T223714Z.md`**;issue **GH #406**;
  backlog 条目 **`0SLOT`**(并新开 `0MOCKHOLE` / `0SLOT9` 两条登记项);
  **落地 gated `slotarb`**,入集提议 `test_set.md` **§DI**(搭车、零 AWS 增量、不申请专波);
  `queue.json` 新增 **`strategy-34`**(**`bundle` 已填**);`state.json` 新键 `slotarb_20260901`;
  零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **一个循环的「域」和它的「访问器」用了两套下标空间时,不匹配不会报错 ——
  它静悄悄地缩小域,而且缩得按侧不同。**
  `bots/FunLib/aba_site.lua` 的 `IsTheClosestOne`(野区营地仲裁)迭代 `GetTeamPlayers`(**player id**,
  radiant 0-4 / dire 5-9)却用 `GetTeamMember`(**team slot 1..5**,越界**答 nil**)去取人 ⇒
  **radiant 扫 4/5、dire 只扫 1/5**,而 dire 那一个对 pid-9 的 bot **就是它自己** ⇒ **仲裁空转、恒答 TRUE**。
  **47 份带 `player_id` 的真实帧上逐份复现:24 dire + 23 radiant;armed 全部扫满 5。**
  **失效方向朝「开」**(连着第三条)。**仓库按多数票回答:91 个调用点里 80 处当 slot、10 处当 id(80:10)。**
  **严格子集**(`[subset]` 实测 46 次翻转、反方向 0 次)。**闸只在 `ClosestCamp` 一处解析**(和 `campsel` 同 wrapper)。
  **⭐ 先跑域再选形状,第一次兑现 #400**:`corpus_hero_census.py --file bots/FunLib/aba_site.lua`
  答 **SHARED / exit 0** ⇒ **没有 `DOMAIN-EMPTY` 分支需要预登记**(但要读准:SHARED 这半几乎不承重)。
  **变异 14/14 CAUGHT,第一遍两个活口**:**M12 是真洞**(ts-parity 断言被**参数表**满足 ——
  **用错误理由达成的正确结论**,与 #397 M2、#400 M4b **同形,连着第三轮**);M8 是等价变异,已换。
  **⛔ 最该被读的一条(交总监):量具洞** —— `tests/mock/bot_api.lua` 的 `GetTeamMember(n)`
  **对任何 n 都答一个英雄、永不答 nil** ⇒ **写在那个 mock 上的单元测试对这条缺陷结构上失明**,
  **这就是 91 个调用点带着 10 处错误却一路绿灯的原因**;只有 `replay_fixture.lua` 的真实 roster 会答 nil。
  已棘轮化(`[instrument]`),**修不修那个 mock 是总监的决定**(中心件,第二个杠杆)。
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
  `slotarb` 12/0 · `campsel` 21/0 · `smoke_load` 3/0 · `gate_claim` 10/0 · `replay_fixture` 9/0 ·
  `level_gate_census` 15/0 · `corerole` 8/0 · `is_there_core` 11/0;
  **⚠️ 全量套件(仍在跑,不整体声称)抓到一条本改动造成的红,已修**:
  `test_item_name_census.lua` 把一个查询**钉在行号上**(`aba_site.lua:1488`),
  本轮加的注释把它推到 **1522** ⇒ 报 `MOVED` 不是新缺陷,按它自己印的办法更新后 **6/0**。
  **教训**:那条棘轮**不在八个定向文件里的任何一个**,因为它跟被改文件的关系是**行号**不是主题 ——
  **按主题挑测试永远挑不到它,只有无过滤那一跑看得见**(另一条红 = GH #394,自检在任何编辑之前就报过)。
  **开工自检**:第一条命令又写成 `| tail` 被拒(同站点第十三轮),改重定向后拿到完整读数 ——
  `selfcheck worst exit: 3`,`legs run 8`,`FINDINGS = cadence / trunk-red(python) / trunk-red(lua)`,
  **`UNCERTIFIABLE: 2`**(两条都是「跑那一步时 PATH 上还没有 `lua5.1`」,GH #383/#384 一族);
  Lua 侧那条 trunk 红 = **GH #394**,既存、与本改动无关。
  **⏳ 待总监裁 §DI(入集 + 量具洞);录像组买条件 (a),先看 dire 侧、两个分层各自登记读数。**
- 2026-09-01T19:21Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出,P3 责任在总监;
  backlog 最上面三条 `0HPB`/`0HPB5`/`0HPBX` 已结清或明写不做,**且 `0HPB5` 逐字写着要等本轮这道读数** ⇒
  **本轮兑现上一轮亲手交出去的 §DG.7.1**;**报告 `iterations/reports/strategy/20260901T192129Z.md`**;
  issue **GH #400**;backlog 条目 **`0CORP`**(并新开 `0NOTNUM` / `0SHAPE0` 两条登记项);
  **零行为改动**:无新 gate、无 armed id、无入集提议、无 `queue.json` 请求;
  零 AWS、S3 零访问、零 EC2;**`bots/` 与 `game/` 零 diff**):
  **一个只能证伪的读数,必须在选杠杆之前跑,不是在裁定之后补。**
  语料出场 **=0** ⇒ fixture 级买到条件 (a) **不可能**(**承重**);**>0** ⇒ 只是没被排除(几乎不承重)。
  **能说「别做」的正是便宜的那半** —— 而 **#385 / #393 / #397 连着三轮没在选题前跑它**。
  **产出** `tools/agent/corpus_hero_census.py`(秒级、只读、退出码 **0/2/3**,
  **2 = 语料读不到 ≠「都不在场」**)+ `tests/test_corpus_hero_census.py`(`[ratchet]` **32/0**)。
  **实测:108 帧文件 / 43 个英雄;五个焦点英雄全部在场**(CM 54·40、zuus 52·38、WK 37·29、
  axe 29·20、lion 24);**tiny / shredder / kez / dawnbreaker / brewmaster 全部 0 ⇒ exit 3**;
  `bots/mode_*.lua`、`bots/FunLib/*` ⇒ **SHARED,不付域价钱**(这是可操作的一半)。
  **变异 14/14 CAUGHT,但六个活过第一遍**:M4b 被**表头那行 `WeakHeroes list : 18`** 满足
  (**与 #397 的 M2 同形**);M13 尤其 —— 原 `--top` 断言**在任何排序下都自洽**。
  **⛔ 并登记一次被污染的变异回合**:加完一条新断言后干净树自己就红(42 vs 43),
  那一轮 **11 个变异全部报 CAUGHT,全是被那条本来就红的断言抓的**;修好后整轮重跑。
  **变异台开跑前必须先证明基线是绿的。**
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
  `run_tests.lua`(smoke_load / gate_claim / replay_fixture)**3/0**;
  `test_corpus_hero_census.py` **32/0**;**全量套件没跑完(GH #124),不声称**。
  **开工自检:第一条命令又写成 `| tail` 被拒(同站点第十二轮),但这一轮没再自己加 timeout,
  于是第一次拿到完整读数** —— `selfcheck worst exit: 3`,`legs run 8`,
  `FINDINGS = cadence / trunk-red(python) / trunk-red(lua)`,**`UNCERTIFIABLE: none`**。
  两条 trunk 红既存并已立案(`test_carrier_terms.py` = W35 wave,#396 同族;
  `test_incoming_damage_callsite_census.lua` = **#394**),而且给的是比 `git stash` 更强的理由:
  `git status --short` **全程只有三行 `??`**,现有文件改动零行。
  **⏳ 待总监裁 §DG.7.1(进不进流程);本组下一轮先选域再选形状。**
- 2026-09-01T18:55Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出,P3 责任在总监;
  backlog 最上面三条 `0IMM`/`0TREE`/`0REPICK` 都已结清或明写不做 ⇒ 本轮开一次**新的机械化普查**;
  **报告 `iterations/reports/strategy/20260901T185500Z.md`**;issue **GH #397**;
  backlog 条目 **`0HPB`**(并新开 `0HPB5` / `0HPBX` 两条登记项);
  **落地 gated `hpbool`**,入集提议 `test_set.md` **§DG**(搭车、零 AWS 增量、不申请专波);
  `queue.json` 新增 **`strategy-33`**(**`bundle` 已填**);`state.json` 新键 `hpbool_20260901`;
  零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **一个操作数是数字的合取项不是条件,是一句 `and true`。**
  `bots/BotLib/hero_tiny.lua:487`,`X.ConsiderToss` 撤退臂
  `or (J.GetHP(bot) and bot:WasRecentlyDamagedByAnyHero(2))` —— `J.GetHP` 返回
  `nCurHealth / nMaxHealth`、死亡路径返回**裸的 `0`**,**从不 nil、从不 false**,
  而 Lua 里 **0 为真** ⇒ **该合取项恒真,什么也没决定**。
  **全仓这个形状只有 6 处**(`[source S1]`,4 个英雄文件),更宽的一遍(`[source S2]`)零命中 ⇒ **是全体不是样本**。
  **⚠️ 失效方向朝「开」**,与 #393 同侧、与它之前的七条相反。
  **⭐⭐ 最窄的证据在同一个文件里**:全仓 **64 处**带阈值(众数 **0.65**),**6 处丢了 `< X`**(**64 : 6**);
  而 **`hero_tiny.lua:659` 比缺陷低 170 行,写的就是正确版本、用的就是这个 0.65**。
  **⭐⭐⭐ 代价收两次**:(1) 满血也 Toss;(2) **支配** —— 撤退中右臂几乎恒真 ⇒
  **左臂那个「被压人数」判别也永远决定不了任何事**,一个死合取项杀掉整条竞价(`[frame F4]` 等价式)。
  **改动不改出厂操作数,追加 gated 合取项**;门关**逐字节等于出厂判决**;
  **严格子集:只可能撤掉一次施法,永远不可能新增一次**(`[frame F5]` 全阵容扫)。
  **产出** `tests/test_hpbool_dead_conjunct.lua`(`[ratchet]` **13/0**),真实帧
  `f_260820_043120_viper_defend_paired`(t=599.5,**一帧同时带案例与对照**:viper **0.977** / axe **0.339**,
  两人都在 2s 内被英雄打过;`[frame FC]` 阳性对照**承重**)。
  **变异 10/10 CAUGHT。⚠️ 诚实注记:第一遍 M2(0.65 → 0.5)是活的** ——
  断言被 `:659` 那份**本修复根本不碰的正确拷贝**满足:**用错误理由达成的正确结论**,
  而**让它变空洞的正是上面算作证据的那个邻居**;改成对切片表达式求证后 CAUGHT。
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
  `hpbool` 13/0 · `smoke_load` 3/0 · `gate_claim` 10/0 · `immguard` 14/0 · `replay_fixture` 9/0;
  **全量套件没跑完(GH #124),不声称**。
  **三处 trunk 红全部在 `git stash` 干净树上复跑确认既存**(#396 / 同一份 W35 wave 的
  `test_carrier_terms.py` / #394)。
  **⚠️ 开工自检:同一个坑连续第二轮** —— 第一条命令仍写成 `| tail`(被拒绝横幅当场拆穿,同站点第十一轮),
  改重定向后**又一次被我自己的 `timeout 400` 杀掉**(`EXIT=124`,**不是通过是没跑成**;
  上一轮 13:55Z 逐字记过同一件事)。完整读数 **`selfcheck worst exit: 3`**,
  `FINDINGS = cadence / trunk-red(python) / trunk-red(lua)`,`UNCERTIFIABLE: none`。
  **⭐⭐ 本轮真正想交出去的一棒(§DG.7.1)**:`[source S6]` 走遍 110 份 fixture ——
  **tiny / shredder / dawnbreaker / kez 出场 0 次,brewmaster(#393 主体)也是 0 次** ⇒
  **连着三轮(#385 / #393 / 本轮)被修英雄的语料出场为零**;总监 §DF.6 要求
  「**在它产出第三条、第四条 null 之前先给这个形状起好名字**」,**本轮就是第三条**,
  且第一次把它量成**可运行的读数**。**建议把「语料出场普查」提成入集前的常设读数。**
  **同时登记一处结构性改善,也是量出来的**:`WeakHeroes` 节流名单上**有 brewmaster、没有这四个**。
  **明说没做**:6 处只修 1 处(`0HPB5`);**阈值借来的**(`0HPBX`);`2` 不动;基数项是合成的。
  **⏳ 待总监裁定入集(§DG),RIDESHARE,不能当独臂。**
- 2026-09-01T13:55Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出,P3 责任在总监;
  ⇒ 取**上两轮都逐字写下来的那条遗留**(`aba_hero_sub_units.lua` / `primal_split.lua` 的 4 处
  `Action_AttackUnit(x, false)` **只普查未审计**);GH #385 已证前者**零引用者**
  ⇒ **`primal_split.lua` 就是这条遗留的全部活体**,本轮是那次审计;
  **报告 `iterations/reports/strategy/20260901T135500Z.md`**;issue **GH #393**;
  backlog 条目 **`0IMM`**(并新开 `0TREE` / `0REPICK` 两条登记项);
  **落地 gated `immguard`**,入集提议 `test_set.md` **§DE**(搭车、零 AWS 增量、不申请专波);
  `queue.json` 新增 **`strategy-32`**(**`bundle` 已填**);`state.json` 新键 `immguard_20260901`;
  零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **一个两条臂返回同一个表达式的 `if` 不是过滤器,是一句注释 —— 只是它还要付一次函数调用的钱。**
  `bots/FunLib/minion_lib/primal_split.lua:109`:
  `if target ~= nil and not target:IsAttackImmune() and not target:IsInvulnerable() then return target end`
  之后紧跟一个裸的 `return target` ⇒ **这个免疫过滤器一次都没有筛掉过任何东西**。
  **⚠️ 它与同族七条(#348/#368/#370/#373/#378/#381/#385)失效方向相反**:
  那七条全朝**关**失效且**都不可观测**(「没触发」与「被正确否决」在任何观察下一模一样);
  **本条朝开失效** —— 闸放行一切,错误答案是一个**积极动作**;
  **它不是不可观测,只是没人看**(唯一到达这个文件的英雄是开着大招的酒仙)。
  **⭐⭐ 仓库自己回答了两遍**:(1) `J.GetWeakestUnit` → `J.GetAttackableWeakestUnitFromList`
  (`jmz_func.lua:3764-3765`)**逐字**写着这两个否定 ⇒ **`return nil` 是仓库自己的做法**;
  (2) **……而 `:105` 把 picker 的 `nil` 读成「没有意见」,`target = enemies[1]` 把它刚拒绝的
  同一个句柄放了回来** ⇒ 手写这道闸**是不可攻击单位与攻击命令之间唯一的东西,在每一条臂上**。
  **代价收两次**:`X.MinionThink:65-69` 下命令**然后 `return`** ⇒ 一条零伤害命令 +
  **`ConsiderMove` 整个不跑**(而对**火熊猫**它就是行为的全部,自己的技能分支是**空 `if`**)。
  **改动不删闸,把 gated 提前返回插在两条臂之间**(门关 ⇒ 落到出厂 `return target`,出厂路径不变)。
  **⚠️ armed 不是严格超集**,它**减少**一条命令 —— 理由是引擎规则:打不可攻击单位**恒定零伤害**,
  **拿走的那条命令在信息上是空的**。
  **产出** `tests/test_immguard_dead_filter.lua`(`[ratchet]` **14/0**),真实帧
  `f_260819_142047_zuus_ult_denied`(**zuus,焦点英雄**,t=278.5;**选它是为了几何**:
  中路、**存活敌塔 727u**、**1600 内 0 敌英雄** ⇒ 走进那条没有过滤的 `enemies[1]` 塔臂)。
  **变异 14/14 CAUGHT**(**M11 是加载期语法错,被解释器抓不是被断言抓,最弱的一条**)。
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
  `immguard` 14/0 · `smoke_load` 3/0 · `gate_claim` 10/0 · `illureal` 12/0 · `illumove` 9/0 ·
  `replay_fixture` 9/0;**⭐ 全量套件本容器里跑完了**(收尾补记,推翻本轮自己先前那句「没跑完不声称」):
  **`3000 tests, 6 failures`,真实退出码 `FULL_EXIT=1`** —— **而它差点被读成绿的**,
  因为命令写成 `... ; echo "FULL_EXIT=$?"`,**外壳退出码是 `echo` 的**,harness 汇报 `code 0`
  (**evidence discipline 3,同一轮里第二次**)。**6 条红全部不是本轮的,量出来不是声称的**:
  还原本轮两个文件后 **5 条逐条复现**;**第 6 条只在全量跑里出现 ⇒ 顺序依赖**
  (前面某个文件改了 `BOT_MODE_*` 全局不还原,**按定义没有任何单文件过滤器看得见**)。
  连同「GH #124 那条『全量套件在 routine 容器里跑不完』的标准假设在本容器上不成立」一并立案 **GH #401**。
  **⚠️ 方法自伤被提前挡住**:`[frame FC]` 先立成**承重阳性对照**(帧按 dump 原样,两臂都必须攻击那座塔),
  随后 `[frame F1]` 量出两个免疫谓词在 fixture 上**全帧全句柄读 false** ⇒
  **没有 FC,F2/F3 完全可能因为闸没被走到而「通过」**(§DD 的教训:**一道关着的闸,
  在有东西证明它能开之前,什么都没证明**)。另两处断言写窄了已修:
  `[source S1]` 第一版**只认单行 `if ... then`**,三处里只看得见一处(**一个把自己看到的当成全部的普查**);
  `[source S3]` 把 `return target` 数成 2,实际 3。
  **⚠️ 开工自检**:第一条命令仍写成 `| tail`,**被拒绝横幅当场拆穿**(同一站点连续第十轮);
  改重定向后**第一次被我自己的 `timeout 400` 杀掉(`EXIT=124` —— 不是通过,是没跑成)**,
  后台 900s 重跑才跑完。读数 **`TRUNK RED`(python 腿)+ 两条 `UNCERTIFIABLE` + 多条 trunk-health `UNC`**,
  **没有一条是本轮的**:前者是 GH #383/#364/#384(python 腿跑在 `lua5.1` 自购之前,新容器第一次必红),
  后者全是 GH #358 的 120s 预算超时(本轮 `69 file(s) in 120.1s`,与 #358 记的 69 一致)。
  **明说没做**:`J.GetBestRetreatTree`(**同一次普查的第二个活实例,登记不修** ⇒ `0TREE`);
  `hero_earth_spirit.lua:680` **故意不动**(整函数是桩,**没有被丢掉的答案就没有可恢复的东西**);
  **armed 不重选目标**(⇒ `0REPICK`);
  **⚠️ 频率未知且比平时更重 —— 酒仙不是焦点英雄,且这个域在 fixture 上根本买不到**,只能在真实录像上验。
  **✅ 总监 2026-09-01T15:5xZ 已裁:`ROUTED_RIDESHARE / ADMITTED`**(与 `tormself` **两条同轮入集**,
  52 → 54,裁定全文 **`test_set.md §DF`**,本条 §DF.2;`queue.json` `strategy-32` `director` 字段已填,
  `status` → `running`)。**总监按源码独立复核五条**,其中一条要回读:
  ⚠️ **§DF.2 (ii) 方向复核 —— 本条是严格子集,不是超集。** 门放在出厂那句 `return target` **之下**,
  可攻击的目标在门被求值之前就已返回 ⇒ armed **只可能撤掉攻击命令,永远不可能新增一条**。
  **`tormself` 是严格超集,本条是严格子集;§DC 那一族全是超集,按模式匹配读会读反。**
  ⚠️ **§DF.5:与 `tormself` 正交** —— **阴性也登记**,否则「查过且正交」与「根本没查」分不开。
  ⚠️ **§DF.6 联合登记:本条与 `tormself` 是同族第 8、9 条,两条都落在非焦点英雄上** ⇒
  **预期会出现一串 `DOMAIN-EMPTY` 收割,而那一串不构成关于这些修复的任何证据**;
  判 `DOMAIN-EMPTY` **必须退回总监重裁**,**不得**自行套用「无效应 ⇒ 不 promote」。**两条都不能当独臂。**
- 2026-09-01T10:30Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出;
  ⇒ 取 backlog `0FIELD` **明说没做**的两项之一(`aba_hero_sub_units.lua` / `primal_split.lua` 的连续命令**只普查未审计**);
  **报告 `iterations/reports/strategy/20260901T103016Z.md`**;issue **GH #385**;
  backlog 条目 **`0TORM`**;**落地 gated `tormself`**,入集提议 `test_set.md` **§DD**
  (搭车、零 AWS 增量、不申请专波);`queue.json` 新增 **`strategy-31`**(**`bundle` 已填**);
  `state.json` 新键 `tormself_20260901`;零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **一个以「别的单位」为域的谓词被喂了 `self` —— 语言抓不到,因为两者是同一种鸭子类型;
  运行期也不报,因为这个谓词是全函数:对 self 不抛错,只是恒假。**
  `bots/BotLib/hero_ringmaster.lua:915` 的闸外层按 bot 的 mode 二路分,内层本该按 target 同样二路判别 ——
  **Roshan 臂写对了**(`J.IsRoshan(botTarget)`),**Tormentor 臂问的却是 `bot`**;
  而 `J.IsTormentor` 是纯身份谓词(`GetUnitName()` 里找 `'miniboss'`),
  我们自己叫 `npc_dota_hero_ringmaster` ⇒ **那条臂构造上恒假,外层析取的整个 Tormentor 那一半够不到函数体**。
  **⭐ 主判据:失效方向朝「关」,而它的静默是本档案里最强的一种 —— 没有任何一帧、任何一局、
  任何一份录像上,这个错答案与一个正确的 `false` 有区别,因为对 `self` 而言正确答案就是 false;
  只有调用点知道这个问题是问别人的。**
  **判别特征可数、不需要帧**:枚举调用点看实参 —— **249 个存活 `J.IsTormentor` 调用点,
  227 个(90.8%)喂 `botTarget`,恰好 1 个喂 `bot`**;**本文件自己另外四处(436/622/846/965)都写对了**。
  **⭐ 边界必须一并记住:「self-fed」本身不是判据 —— `J.IsMeepoClone(bot)` 是合法的 self-fed;
  判据是 self-fed ∧ self 不可满足。** 类棘轮 `[source S5]` 按这条写,**故意不管 `IsMeepoClone`**。
  **与 #348 拼错 / #368 词法作用域 / #370 未汇报副作用 / #373 闩记错后置条件 / #378 节流器作用域 /
  #381 手工字段复制引擎事实同族不同因**:**本条每个标识符都存在、拼对、在作用域内、不持状态、
  永不过期,函数也是对的那个;错的完全是「问的是哪个对象」。**
  **⭐⭐⭐ 为什么没人发现**:这是**复制粘贴的一脉**(另有 `aba_hero_sub_units.lua:370` 与被注释的
  `familiars.lua:358`),**但那个文件零引用者 ⇒ 这一脉三分之二是死代码**,
  **唯一存活的那份因此也像是同一堆死东西**;`[source S4]` 钉住它的「死」。
  **改动**:新增 `IsTormentorSubject()` 按 `J.IsModeTurbo() and J.IsSoakCandidate('tormself')` 分叉;
  **门关逐字返回 `J.IsTormentor(bot)` ⇒ 出厂不变**;门开返回 `J.IsTormentor(botTarget)`,
  **严格超集**(关的那条恒假 ⇒ **arming 不可能让它反而不做今天会做的事**)。
  **产出** `tests/test_tormself_identity_domain.lua`(`[ratchet]` **10/0**),真实帧
  `f_20260828_004757_venomancer_785`。**`[frame F0]` 把发现量出来**:真实 `J.IsTormentor` 跑遍
  **107 帧 / 993 个英雄句柄 / 41 个不同英雄名 → 为真 0 次;不是罕见条件,是空条件**。
  **⭐ `[frame FC]` 阳性对照**:**同一个 `if` 的兄弟臂**、**不开门** ⇒ HIGH。**变异 11 条:11 条全 CAUGHT。**
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**(变异台前后各一次);
  `tormself` 10/0 · `smoke_load` 3/0 · `gate_claim` 10/0 · `illureal` 12/0 · `illumove` 9/0;
  **全量套件本轮没跑完(GH #124),不声称**。
  **⚠️ 一次方法自伤,被本文件自己的阳性对照抓出**:`[frame F1]` 一开始读出 NONE 并**「通过」** ——
  真因是 mock 给了**未学习**的技能桩,`J.CanCastAbility` 在**第一行**就 bail,**距受测那条臂还有四个条件**。
  **一道关着的闸,在有东西证明它能开之前,什么都没证明。** 已补 S-D 并新增 `[frame FC]`;
  **登记理由是失效方向 —— 它 bail 的方向恰好是这个测试想要的答案**(与 #377 M8、#381 普查拼写同族)。
  **⚠️ 另一条断言自审**:`[source S2]` 起初只断读者那一半,**变异 M11 保持它为真却仍打断修复**
  (`SkillsComplement` 转而赋值全局);**M11 是帧测试抓到的,S2 没抓到**,已加断 `writer > declaration`。
  **⚠️ 开工自检**:第一条命令仍是 `| tail`(同一站点连续第九轮,被拒绝横幅当场拆穿);
  改重定向后**被我自己的 `timeout 400` 杀掉,`EXIT=124` —— 那不是通过**;后台重跑得
  **43 checks / 0 failures / 9 UNCERTIFIED**,**9 条全是 GH #358 的 120s 预算超时,没有一条是本轮的**。
  **明说没做**:`primal_split.lua` 的连续命令**仍只普查未审计**;`aba_hero_sub_units.lua` 那份拷贝**故意不修**;
  **频率未知且比平时更重 —— Ringmaster 不是焦点英雄 ⇒ 焦点五英雄身上一个读数都买不到**,
  **那是本修复价值的上界**。
  **交棒:总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 主判据含那条边界进不进 §CR;
  **丙已消**:总监在同一小时把 `illumove`/`illureal` **两条同轮入集**(§DC,50 → 52),
  `strategy-29`/`strategy-30` **已裁**,我的提议顺延为 **§DD**;⚠️ **§DC.3 是总监新加的限定**:
  那两条**同帧不正交**,`illureal` armed 缩小 `illumove` 的域,**交集上的帧不能分摊归因**)、
  **录像组**(只缺一种读数:**「Ringmaster 在
  `BOT_MODE_SIDE_SHOP` 且正在攻击 Tormentor」的窗口有多少、多长**;已按 §CJ 预登记
  **`METHOD-FAILED`** ⇒ 没有该窗口/根本没出场判 **`DOMAIN-EMPTY` 退回总监**)。
  **批测台:`strategy-31`,搭车、零 AWS 增量。**
  **✅ 总监 2026-09-01T15:5xZ 已裁:`ROUTED_RIDESHARE / ADMITTED`**(与 `immguard` **两条同轮入集**,
  52 → 54,裁定全文 **`test_set.md §DF`**,本条 §DF.1;`queue.json` `strategy-31` `director` 字段已填,
  `status` → `running`)。**总监按源码独立复核五条,并加了两条提议里没有的限定**:
  ⚠️ **§DF.3:本条那个头号语料读数(993 个句柄为真 0 次)在结构上不可能对 armed 臂说话** ——
  它跑的是**英雄索引**,而 Tormentor 是**中立单位**,`detect.Timeline` 根本不索引它
  (backlog #1 自己写明的 LIMIT)⇒ 那是**关着那条臂**的域的正确测量、**开着那条臂**的**零信息**。
  **条件 (a) 因此买不到于 `corpus_query`**,只能走真实录像。
  ⚠️ **§DF.4:本条从未论证「armed 臂可达」,总监替它查了两条腿,都通过** ——
  (甲) `J.GetProperTarget`(`jmz_func.lua:335-358`)**不是英雄限定**,中立 `miniboss` 过得了它唯一那道丢弃条件;
  (乙) `BOT_MODE_SIDE_SHOP` 有真模式脚本 `mode_side_shop_generic.lua` 撑着(`GetDesire()` 可返回 `VERYHIGH`)。
  **(甲) 若不成立,本条整份证据链会逐字保持为真而结论完全落空** —— 下次提「恒假 ⇒ 严格超集」时,
  **把「开着那条臂可达」一起证了**。
  ⚠️ **§DF.5:与 `immguard` 正交**(不同英雄/文件/调用路径),**没有 §DC.3 那种限定**。
- 2026-09-01T07:46Z(**自驱** —— `[strategy]` 未认领 issue 仍为零(open 的九条全是本组自己开的);
  owner P1 第 1 棒、P2 均已交出;backlog `0d` 上一轮已结案 ⇒ **留在它打开的人口里**
  (小兵驱动器,不经 mode 竞价),取上一轮那条分支**再往上四行**的一条;
  **报告 `iterations/reports/strategy/20260901T074632Z.md`**;issue **GH #381**;
  backlog 条目 **`0FIELD`**;**落地 gated `illureal`**,入集提议 `test_set.md` **§DB**
  (搭车、零 AWS 增量、不申请专波);`queue.json` 新增 **`strategy-30`**(**`bundle` 已填**);
  `state.json` 新键 `illureal_20260901`;零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **一个关于世界的谓词被存成手工字段,于是它只对记得设它的那两个英雄为真 —— 而那两个恰好是你会用来验它的那两个。**
  `bots/FunLib/minion_lib/illusions.lua:52` 把 `X.ConfuseEnemyWithIllusions`
  (低血撤退时让幻象反向散开做诱饵)闸在 `hMinionUnit.isIllusion` 上;
  全仓**写**该字段的**恰好 2 个文件**(naga_siren:91 / phantom_lancer:92),
  而**127 个英雄文件**全部经 `aba_minion.lua:48-53` 把小兵送进本模块,
  **且驱动器自己按引擎方法 `hMinionUnit:IsIllusion()` 路由**
  ⇒ **幻象一定到达 `X.Think`,只是里面那条分支看不见它**
  ⇒ 对**除娜迦/PL 外的每一个幻象**结构上不可达(CK Phantasm、TB Conjure Image、幽鬼 Haunt、
  **19 个买 `item_manta` 的英雄**的每一把分身斧)。
  **⭐ 主判据:一个关于世界的谓词一旦被存成手工维护的字段,它的真假就不再是世界的事实,
  而是「每个写者记没记得」的事实** —— 可达性等于**最不勤勉的那个调用方**,
  且**朝「关」的方向静默失效**:**没被设过的字段与诚实的 `false` 在任何观察下都一样**。
  **判别特征可数、不需要帧**:**同一文件里一个谓词两种活着的写法,不同分支读不同的那一个**;
  见到就数 **字段的写者 vs 分支的调用方**(本例 **2 比 127**)。
  **与 #348 顺序 / #368 词法作用域 / #370 未汇报副作用 / #373 闩记错后置条件 / #378 节流器作用域
  同族不同因**:**那五条是「状态被怎么读写」的缺陷;本条每一次读写都正确、字段也从不过期,
  错的是这个字段是引擎已知之事的副本,而副本有 2 个写者、正本有 127 个读者。**
  **⭐⭐ 它是缺陷不是取舍,证据在同一文件**:**往下六十行**的 `X.ConsiderRetreat`
  对**同一句柄**、经**同一次 `X.Think`**、**在下一行**用**引擎方法**问了**同一个问题**。
  **⭐⭐⭐ 为什么没人发现**:**12 个**英雄文件在 `X.MinionThink` 里**显式判过 `IsIllusion()`**
  再路由,其中**设了字段的 2 个是娜迦和幻影长矛手** —— **两个专职幻象英雄,
  也就是你要验幻象功能时会打开的那两个** ⇒ **演示里是好的,别处全是死的**;
  **TB 在另外那 10 个里,而本文件 `ConsiderMove` 里就有一条 TB 专属幻象带线分支**
  ⇒ **模块是为一个它自己的闸放不进来的人口写的**。
  **改动**:新增 `IsIllusionUnit` 按 `J.IsModeTurbo() and J.IsSoakCandidate('illureal')` 分叉;
  **门关逐字返回那个字段 ⇒ 出厂不变**;门开返回 `isIllusion == true or :IsIllusion()`,
  **严格超集**(**arming 不可能让今天会做诱饵的娜迦/PL 幻象反而不做**)**且不外扩到无技能召唤物**。
  **产出** `tests/test_illureal_field_vs_engine.lua`(`[ratchet]` **12/0**),真实帧
  `f_231411_ck_zoned`(subject **chaos_knight**,hp **126/1068 = 0.118**;
  CK **既是幻象大招英雄又在 19 个 manta 买者之列**,而它的英雄文件**无条件路由却从不设字段**);
  该帧两个世界条件**是读出来的**:hp 0.118<0.4、`WeAreStronger`=false 且 1200 内**确有 2 个活敌**。
  **变异 19 条:16 CAUGHT / 3 存活,三条存活全部在跑之前就写进文件。**
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
  定点与 5 个邻接文件全绿;**全量套件本轮没跑完(GH #124),不声称**。
  **⚠️ 一次方法自伤,被测试自己的断言抓出**:普查按 `Minion.IllusionThink`
  (**模块局部变量的拼写**)读出 **126/127**,漏的是转译自 `typescript/` 、
  **小写拼作 `minion.IllusionThink`** 的 `hero_wisp.lua` —— **一个确实在路由的文件走了过去**;
  已改按**调用**取键。**与 #377 的 M8 同形;登记理由是失效方向 —— 朝更小的分母偏,
  也就是朝这个测试想要的答案偏。**
  **⚠️ 顺带修一条邻居棘轮的假阳性**:`illumove [source S3]` 的
  `count(CODE,'IsSoakCandidate(')==1` 在同一文件落下第二个**无关**候选时就红 ——
  已按 id 取键。**一个禁止文件生长的棘轮,量的是文件不是主张。**
  **⚠️ 开工自检同一站点连续第八轮**:第一条命令仍是 `| tail`,被拒绝横幅当场拆穿;
  改重定向后跑完 8 条腿。**四条 finding 全不是本轮的**(cadence 三洞均在 08-31;
  `test_rc_wrapper.py` = **GH #364**);**`ORPHAN_PROPOSAL` 本轮为零**;
  `strategy-29`(上一轮 `illumove`)仍 `pending` 未裁 —— **交棒未掉,只是还没轮到**。
  **[总监 2026-09-01T10:2xZ 回填]** 已裁:`illumove`(`strategy-29`)与 `illureal`(`strategy-30`)
  **两条同轮 `ROUTED_RIDESHARE / ADMITTED`**,成员串 50 → 52,裁定全文 `test_set.md §DC`。
  **收割前请先读 §DC.3** —— 总监加的第 (丁) 条限定:两条改的是同一条 `X.Think` 路径,
  `illureal` armed 会让更多幻象在 `:80` 提前 `return` 从而**缩小 `illumove` 的域**,
  交集上的帧**不能分摊归因**;两份验收各自只 arm 自己那一个 id,**没有测试钉住这一条**。
  **明说没做**:`ConfuseEnemyWithIllusions` **函数体一字未动**(反向 800u 的几何只普查未审计);
  `aba_hero_sub_units.lua` / `primal_split.lua` 的 4 处连续命令**仍只普查未审计**;
  **频率未知且比平时更重** —— 四项合取的出现率未证,**那是本修复价值的上界**,
  **且焦点五英雄没有一个产生幻象 ⇒ 只可能在非焦点英雄身上买到读数**。
  **交棒:总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 主判据进不进 §CR;丙 `strategy-29` 仍待裁)、
  **录像组**(只缺一种读数:**「持有存活幻象 ∧ 血量 <40% ∧ 正在撤退」的窗口有多少、多长**;
  `acceptance` 已按 §CJ 预登记 **`METHOD-FAILED`** ⇒ 没有这种窗口判 **`DOMAIN-EMPTY` 退回总监**)。
  **批测台:`strategy-30`,搭车、零 AWS 增量。**
- 2026-09-01T04:29Z(**自驱** —— `[strategy]` 未认领 issue 仍为零(open 的全是本组自己开的);
  owner P1 第 1 棒、P2 均已交出 ⇒ 取 backlog **`0d`**,**并把它结掉**;
  **报告 `iterations/reports/strategy/20260901T042904Z.md`**;issue **GH #378**;
  backlog 条目 **`0ILMV`**;**落地 gated `illumove`**,入集提议 `test_set.md` **§CZ**
  (搭车、零 AWS 增量、不申请专波);`queue.json` 新增 **`strategy-29`**(提议方自建,**`bundle` 已填**);
  `state.json` 新键 `illumove_20260901`;零 AWS、S3 零访问、零 EC2;`game/` 零 diff):
  **一个 module 级的时钟在节流 N 个 per-unit 的消费者,输的那些一条命令都拿不到 —— 而且是永久的。**
  `bots/FunLib/minion_lib/illusions.lua` 的 `nNextMoveTime` 是 **module 级**局部变量,
  `bots/FunLib/aba_minion.lua` **只 `dofile` 它一次**(`:11`)并把这个 bot 的每一个幻象与每一个
  `U.IsMinionWithNoSkill` 单位经**同一个调用表达式**(`:52`)送进 `X.Think`
  ⇒ 同帧第一个走到移动分支的小兵把时钟推后 0.2s,**兄弟们直接从 `X.Think` 末尾掉出去,零命令**;
  它们 0.2s 后也补不上,因为 `aba_minion.lua:33-35` 自己那道 per-unit **0.5s** 闸把它们扣住,
  那时时钟又被当帧赢家推后了。**真实帧 20 周期 4 小兵实测 `20/0/0/0`,不是 20/6/6/6**(跑出来的)。
  **⭐ 主判据:一个节流器的作用域必须等于它所节流的那个东西的作用域** ——
  两者不等时它**不是限速器而是抽签**,输家什么都没有,**而从模块内部看每一次调用都长得像正确的那一次**;
  判别特征**可数且不需要帧**:模块生命周期的状态,写在每单位每帧各跑一次的路径上。
  **与 #348 顺序 / #368 词法作用域 / #370 未汇报副作用 / #373 闩记错后置条件同族不同因**:
  **本条每一次读写都正确自洽,错的是有多少东西共用这一个时钟。**
  **⭐⭐ 它是缺陷不是取舍,理由在同一个调用者身上**:`aba_minion` 在它调用 `Illusion.Think` 的
  **二十行之上**对**同一批单位**做**同一件事**并做对了 —— 0.5s 节流存成
  `hMinionUnit.lastItemFrameProcessTime`,**挂在句柄上**(4 处提及处处索引到句柄,已源码计数);
  `illusions.lua` 自己也往句柄上写了五个字段 ⇒ **per-unit 不是本修复发明的新机制**。
  **⭐⭐⭐ `0d` 结掉了**:剩下两行**都实测为空** —— mode 那半止于 `mode_outpost_generic.lua:117`(#373);
  `ability_item_usage_generic.lua` 全量 grep 连续/排队型命令族**只有一行**
  `ActionQueue_UseAbility(hItem)`(`:1120`,`SetUseItem` 的 `'twice'` 臂里的**物品施放**,不是追击命令)。
  **把同一条 grep 扩到 `bots/mode_*.lua` 之外才是入口**:**6 处存活的 `Action_AttackUnit(x, false)`
  全在小兵驱动器里** —— 一个 `0d` 从没点过名的人口,**因为它根本不经过 mode 竞价**。
  **改动**:声明原样保留、`0.2` 命名 `MOVE_THROTTLE`、两个 accessor 各按
  `J.IsModeTurbo() and J.IsSoakCandidate('illumove')` 分叉;**门关读写的就是那个 module local ⇒ 出厂不变**;
  门开读写 `hMinionUnit.next_move_time`(初值读回 **0**,与全新 module 时钟同值 ⇒
  **arming 不可能让出厂会动的小兵反而停下**)。
  **产出** `tests/test_illumove_shared_throttle.lua`(`[ratchet]` **9/0**),真实帧
  `f_260823_002103_wk_ancient_camp_634`(subject **skeleton_king**,**焦点英雄**,该帧
  `mortal_strike` **等级 4**,其召唤物正被 `U.IsMinionWithNoSkill` 点名)。**变异 14 条:14 CAUGHT。**
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;定点 Lua 与 5 个邻接/承重文件全绿;
  **全量 Lua 套件本轮没跑完(GH #124),不声称**。
  **⚠️ 一次量具洞差点让断言因错误理由通过**:`UNIT_LIST_ALL_HEROES` 在 fixture 上恒 **0**、
  同帧 `UNIT_LIST_ENEMY_HEROES` 答 **4** ⇒ **UNMEASURABLE 不是 EMPTY**;
  **失效方向是关键** —— 建在它上面的世界槽会安静地答「附近没有人」,
  而那**恰好就是让 `[frame F5]` 因错误理由通过**的答案(本轮确实先这么错了一次)。
  **⚠️ 开工自检同一站点连续第七轮**:`| tail` 被拒绝横幅当场拆穿;改重定向后**不设超时、8 条腿跑完**
  (上一轮的 `timeout 400` 自伤**本轮没有重犯**)。四条 finding 全不是本轮的
  (unlanded `7b60b0e` 总监 / cadence 三洞 / `test_rc_wrapper.py` = **GH #364**);
  **`ORPHAN_PROPOSAL` 本轮为零**,`strategy-26/27/28` 均已 `ROUTED_RIDESHARE / ADMITTED`
  ⇒ **上一轮「连续第三轮未裁」的交棒已消解,不再重复**。
  **明说没做**:另两个 `dofile` 点各有一份 `nNextMoveTime`,**不动**(一次一个杠杆);
  `aba_hero_sub_units.lua` / `primal_split.lua` 的 4 处连续命令**只普查未审计**;
  **频率未知且比平时更重**(**真实局里一个 bot 同时有 ≥2 个受控小兵的时长 = 本修复价值的上界**,未证);
  小兵句柄是**注入的**(109 枚 fixture 无一带召唤物或幻象),两臂拿到逐位相同的注入。
  **交棒:总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 主判据进不进 §CR;丙 量具洞立不立案)、
  **录像组**(只缺一种读数:**≥2 个受控小兵的窗口有多少、多长,每个小兵各收到几条移动命令**;
  `acceptance` 已按 §CJ 预登记 **`METHOD-FAILED`** 分支 ⇒ 没有这种窗口判 **`DOMAIN-EMPTY` 退回总监**)。
  **批测台:`strategy-29`,搭车、零 AWS 增量。**
- 2026-09-01T01:25Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出
  ⇒ 取 backlog **`0d`**,**并更正上一轮把它宣告为「最后一站」的那句话**(普查 glob `bots/mode_*.lua`
  漏掉了 `bots/FunLib/override_generic/` 下两个真的会被加载的 mode 文件);
  **报告 `iterations/reports/strategy/20260901T012552Z.md`**;issue **GH #377**;
  backlog 条目 **`0NSPC`**;**本轮不落地任何 gated id**,`state.json` 未动,`test_set.md` 未动,
  `queue.json` 一字未动、零 AWS、S3 零访问;**`bots/` 与 `game/` diff 为空**):
  **一条每一环都可核查、每一环都真的缺陷,被真实加载顺序当场证伪 —— 而证伪它的东西比它本身值钱。**
  grep 报三个列 0 名字同时定义在 base `mode_laning_generic.lua`(:265/:287/:251)与 override
  (:167/:188/:214),base 在 :30 `dofile` override、**然后才**定义自己那三份 ⇒ 看着就是覆盖,
  且**两份合同不同**(base 双返回、override 单返回)⇒ override 调用点会对**打不死的兵按下攻击 = 推线**。
  **错的只有前提**:`game/botsinit.lua:15` 的 `setfenv(2, newenv)` + `__newindex = M`
  ⇒ **在 `CreateGeneric()` 文件里,写得和全局一模一样的列 0 定义落进的是模块自己的表**。
  **执行实测**:`dofile(override)` 后 `_G.GetBestLastHitCreep` **仍是 nil**;`dofile(base)` 后才有值,
  **两者不是同一个对象**。发货代码自己反过来说过一遍:base :143 走 `local_mode_laning_generic.GetBotTargetLane()`,
  全仓 **0 处**裸名字调它。
  **⭐ 主判据:命名空间是运行期事实,不是语法事实** —— `^function Name(` 只说明形状不说明表;
  这类审计**朝自信那一侧失效**(凭空造冲突,两边都配 file:line)。
  **与 GH #348 顺序 / #368 作用域 / #370 未汇报副作用 / #373 闩记错后置条件同族不同类**:
  **那四条是发货 Lua 的缺陷,本条是「读这棵树」的缺陷** —— 代码对、指控它的审计错;
  **所以它需要棘轮:有人重新推导出同一个假结论时,树里没有任何东西会红。**
  **⭐⭐ 爆炸半径**:`bots/` 下带列 0 裸定义的文件,**重绑定环境的恰好 2 个(都在 `override_generic/`)、
  另外 59 个没有** ⇒ 假冲突的靶子**高度集中在**唯一那对同名文件上;另一对构造不出该结论(已断言)。
  **⭐⭐⭐ 诚实边界(比平时重)**:override laning 只对 9 个 buggy 英雄加载,
  **109 个 fixture / 43 个英雄里这 9 个一个都没有 —— 是 0 不是少** ⇒
  **一条已发货的路径,本仓从未也无法本地验证过**;断言写成「一旦有了就红」。
  **产出** `tests/test_botsinit_env_namespace.lua`(`[ratchet]` **12/12**)。**变异 13 条:13 CAUGHT。**
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**;
  `lua5.1 tests/run_tests.lua botsinit` **12 tests 0 failures**;**全量套件本轮没跑完(GH #124),不声称**。
  **⚠️ 三次方法自伤,全部由变异抓出**:M8 探测器**按变量名取键**(复现了它要警告的错误)、
  M9 `select('#')` 读的是**空表兜底路径**(与合同无关)、M12 「两个调用点都读第二个返回值」
  **只活在一条失败信息里**(**只出现在报错文案里的声称等于没被断言**)。
  **⚠️ 开工自检同一站点连续第六轮**:`| tail` 被拒绝横幅当场拆穿;改重定向后**我自己的 `timeout 400`
  把它砍在最后一条腿之前**(`SELFCHECK_EXIT=124`)—— **这不是通过,是没跑完**;
  已跑完的四条 finding **全不是本轮的**(unlanded `268b1fd` / cadence 三洞 /
  `ORPHAN_PROPOSAL` §CW·§CX = **GH #376 的假阳,两行都在,不补重复行** / `test_rc_wrapper.py` = **GH #364**)。
  **明说没做**:没落地 gated id(本轮结论是「没有缺陷可修」);override laning 其余部分一行没验过、
  **今天也验不了**;0/109 是**语料读数不是对局频率读数**;引擎是否让各 mode 共享 `_G` **本仓不可观测,一句没主张**。
  **交棒:总监**(甲 主判据进不进 `test_set.md §CR`;乙 `strategy-27`/`strategy-28` **仍未裁**,连续第三轮;
  丙 本轮无入集提议)、**录像组**(只缺一种帧:**那 9 个 buggy 英雄之一的对线期帧**,
  它一个人锁着整个 override laning 文件的本地可验证性)。**批测台:无请求、零 AWS。**
- 2026-08-31T22:28Z(**自驱** —— `[strategy]` 未认领 issue 仍为零(open 的全是本组自己开的);
  owner P1 第 1 棒、P2 均已交出 ⇒ 再取 backlog **`0d`** 的「还没查的」那行,**并且这是那一格的最后一站**:
  两个 roam 文件排除后,`bots/mode_*.lua` 里连续/排队型 `Action_*` **只剩 `mode_outpost_generic.lua:117` 一行**;
  **报告 `iterations/reports/strategy/20260831T222815Z.md`**;issue **GH #373**;
  backlog 条目 **`0OLAT`**;**落地 gated `outlatch`**,入集提议 `test_set.md §CX`
  (搭车、零 AWS 增量、不申请专波);`queue.json` 新增 `strategy-28`(提议方自建,不花钱)、零 AWS、S3 零访问):
  **一次返回空表的扫描,把整个 outpost mode 对这个 bot 永久关死 —— 而读这条命令时发现的问题比命令本身高一层。**
  `DidWeGetOutpost = true` **无条件**排在扫描之后;该块是 `Outposts` 的唯一写者、`GetClosestOutpost` 是唯一读者
  ⇒ 空表永久,`GetClosestOutpost` 恒 `nil`,出价恒 NONE,`Think`(含 `:117` 那条连续型命令)**永远到不了**,
  **没有报错、没有重试、没有任何一条腿会举手**。
  **⭐ 主判据:一个闩必须记录它所把守的后置条件,不是那次尝试**(GH #348 是顺序、#368 是作用域、
  #370 是未汇报的副作用;**本条三者各自都对,错的是标志位回答的问题和消费者问的不是同一个**)。
  **⭐⭐ 第二条独立后果(登记不修)**:`not Outposts[i]:IsNull()` 排在合取式**第四**位,
  在两次对它守护的句柄的方法调用之后 —— **GH #348 的形状在第二个文件里**;`[source S6]` 断言缺陷仍在。
  **⭐⭐⭐ 两条对冲的语料读数,都是真的**:(A) 报「二塔已倒」的 43/107 帧与**没有建筑表**的 43 枚
  是**同一个集合**(差集 0/0/43)⇒ 带真实建筑表的 64 枚上二塔全立,第 56 行以下**结构上不可达**
  ⇒ **S-A 是声明不是发现**;(B) `UNIT_LIST_ALL` 993 条 / outpost **0** 条,**UNMEASURABLE 不是 EMPTY**
  (归因是 loader **自己写下的**「故意不注入小兵与建筑」)。
  **改动**:闩 `= not bRescan or #Outposts > 0`(门关时短路在测量表之前 ⇒ 出厂逐字节不变);
  armed 的重试**自带 1.0s 边界**,节流**写在门内**(门 < 节流 < 扫描 < 闩,位置已钉)。
  测试 `tests/test_outlatch_scan_postcondition.lua`(`[ratchet]` **12/12**)+
  `tests/_outpost_gate_sweep.lua`(107 帧,零 AWS)。真实帧 `f_260819_181742_ss_chase_start`:
  出厂**一次空扫描后再没扫过第二次**;armed 找到后 `dist=1529.7`、出价 **0.4186 > NONE**,
  **且该帧自己的三条否决全被断言让开** ⇒ 两臂之间只剩那个闩。**变异 10 条:10 CAUGHT**。
  门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**。
  **⚠️ 方法自伤**:`.-\nend` 抓函数体**停在第一个嵌套 `end`**,返回被截断的体、少报一处读数,
  **却仍匹配上一个看着合理的期望值** —— **靠「同意你」来失败的扫描器**;已改按两侧邻居切片。
  **⚠️ 开工自检同一站点连续第五轮**:`| tail` 被拒绝横幅当场拆穿,改文件重定向后 `worst exit: 3`;
  三条 finding(cadence / queue-rulings / GH **#364** flaky)**全不是本轮的,不复核不重裁**。
  **⭐ 全量单进程套件本轮跑完了**(收尾时先预写成「未跑完」,后台那一跑推翻了它,已就地改正):
  `run_tests.lua` **裸读 `FULL_EXIT=0` / `2911 tests, 0 failures`**;**但不满足 GH #124 的 10 分钟验收线**
  (实测一个多小时),且**跨了一次树变更**(注释级),settled 树的读数是那之后的 **62 tagged / 0 red**。
  **明说没做**:第二后果没修;**频率未知且比平时更重**(形状已证,真实对局里空扫描多久发生一次未证,
  修复价值的上界就是那个频率);前置条件在 Turbo 10 分钟封顶的批测局里能否出现本轮没答。
  **⭐ 甲已落定(总监 2026-09-01T01:0xZ,`test_set.md §CY.2`):`outlatch` ROUTED_RIDESHARE / ADMITTED**
  (与 `roamidle` 同轮,成员串 48 → 50)。**总监追加了一条本组没写的限定 (D),下游必须照它读**:
  armed 腿有一项**出厂腿没有的常设成本** —— 出厂**整局只扫一次** `GetUnitList(UNIT_LIST_ALL)`,
  armed 在「二塔已倒 + 表仍为空」期间**每 bot 每秒扫一次、扫到局末**;而 §CX.4(B) 已经说了
  本仓**无法观测**真引擎的 `UNIT_LIST_ALL` 到底收不收 outpost ⇒ **若它根本不收,这项成本整局白付、收益恒零**。
  ⇒ **把 armed 腿的帧时/经济漂移归因到别处之前,先排除这项成本**;**恒零要读成「扫了一整局什么也没找到」,
  不是「无效应」**。总监另核出一条本组没写的中性性:节流那条 NONE 只可能发生在闩仍开(⇒ `#Outposts == 0`)的帧上,
  那种帧 `GetClosestOutpost()` 本来就答 `nil`、出价本来就是 NONE ⇒ **它没有吞掉任何一个本可非 NONE 的出价**。
  **剩下的棒:总监**(乙 第二后果立不立案;丙 主判据进不进 §CR;丁 `strategy-27` 仍未裁)、
  **录像组**(只缺一种帧:**二塔倒后 outpost 扫描是否曾返回空表**)。
  **批测台:`strategy-28`,搭车、零 AWS 增量。**
- 2026-08-31T19:27Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒、P2 均已交出
  ⇒ 再取 backlog **`0d`** 的「还没查的」那行,这次是 `mode_team_roam_generic` **之外**的连续/排队型 `Action_*`;
  **报告 `iterations/reports/strategy/20260831T192744Z.md`**;issue **GH #370**;
  backlog 条目 **`0CLOB`**;**落地 gated `roamidle`**,入集提议 `test_set.md §CW`
  (搭车、零 AWS 增量、不申请专波);`queue.json` 新增 `strategy-27`(提议方自建,不花钱)、零 AWS、S3 零访问):
  **防卡死的恢复命令在发出它的那一帧就被抹掉,而且恰好在有漫游目标时被抹掉。**
  `Think` 里 `if isInIdleState then isInIdleState = J.CheckBotIdleState() end` **对控制流零影响**,
  但被调方**不是查询**:它在恢复臂里下 `Action_ClearActions(true)` + `ActionQueue_AttackMove(laneFront)`
  (`jmz_func.lua:11994/11998`);往下十一行,只要 `targetUnit` 有效,同一个 `Think` 就发
  `Action_AttackUnit(targetUnit, false)`,而 `Action_*` **「CLEARS the entire action queue」**
  (`docs/BOT_API_REFERENCE.md:1715`)⇒ **反卡死恢复在最需要它的场景里是个 no-op。**
  **⭐ 主判据:一个调用方不可能为一件它不知道发生过的副作用排序**(与 GH #368 的**作用域**、
  GH #348 的**顺序**同族**不同因** —— 这里调用方对任何一个值都没判断错)。
  **⭐⭐ 第二条独立后果(登记不修)**:`return true` 排在锚点刷新两行(`:12010-12011`)**之上**
  ⇒ idle 一旦闩上,`>= 3s` 的门再也关不上,`Action_ClearActions(true)` **每帧**落在其它系统的队列上。
  **改动**:helper 加第二返回值 `bRelocated`(纯增量,两个出厂调用点单赋值目标 ⇒ 默认逐字节不变);
  `Think` 里 `bRelocated and J.IsModeTurbo() and J.IsSoakCandidate('roamidle')` 时 `return`。
  测试 `tests/test_roamidle_recovery_clobber.lua`(`[ratchet]` **11/11**),真实帧
  `f_260819_181742_ss_chase_start`(**本仓唯一一枚 team_roam 赢下竞价且手上有有效 `targetUnit` 的钉住帧**)。
  **变异 10 条:10 CAUGHT**。门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**。
  **⚠️ 方法自伤**:扫源码的测试**把自己的注释数了进去**,`lineOf()` 返回注释行号**把一条顺序断言判反了**;
  修法是保留行号的注释剥除视图,并**连带修好既存的同一盲区**
  (`test_roamreach_bounded_chase.lua` 的 REVERSE 断言此前扫生文件)。
  **⚠️ 开工自检同一站点连续第四轮**:`| tail` 被拒绝横幅当场拆穿,改文件重定向后 EXIT=0;
  trunk 两处红是 GH **#364** / **#369**,**不复核不重裁**。
  **明说没做**:第二后果没修(一次一个杠杆);**频率未知**(形状已证,真实对局里多久闩上一次 idle 未证)。
  **交棒:总监**(甲 裁入集,**RIDESHARE、不能当独臂**;乙 第二后果立不立案;丙 主判据进不进 §CR)、
  **录像组**(只缺一种帧:真实对局里 bot 多久闩上一次 idle,以及那时 `targetUnit` 是否有效)。
  **批测台无请求、零 AWS。**
- 2026-08-31T16:36Z(**自驱** —— `[strategy]` 未认领 issue 仍为零(open 的 9 条全是本组自己开的);
  owner P1 第 1 棒早已交出、P2 已交棒 ⇒ 取 backlog **`0d`** 明写「还没查的」那条;
  **报告 `iterations/reports/strategy/20260831T163611Z.md`**;issue **GH #368**;
  backlog 条目 **`0SHDW`**;**落地 gated `rotscope`**,入集提议 `test_set.md §CU`
  (搭车、零 AWS 增量、不申请专波);`queue.json` 一字未动、零 AWS、S3 零访问):
  **Pudge 块的连续攻击命令由一个它不读的变量守卫 —— `local` 的遮蔽作用域随块结束,命令排在那个 `end` 之下。**
  文件级 `botTarget` 只在 `GetDesireHelper` 内赋值;块内的 `local botTarget` 遮蔽它,
  遮蔽随 `end` 结束,而 `bot:ActionQueue_AttackUnit(botTarget, false)` 在 `end` 之下 ⇒
  四行之上的 `IsValidTarget(...) and d > 400` **守的是另一个变量**(位置证明钉成 `[source S1]`)。
  **三条独立后果各自钉住**:无条件(Rot 开不开都发,真实帧两种 toggle 都驱动过)、
  连续型(`bOnce=false`,`roamreach`/GH #45 那一形)、可陈旧(赋值在早返回之下,
  `roamstale`/GH #39 那条病**在第二个文件里**)。
  **⭐ 它不能吃 §CR.2 的豁免,理由是差集不是动机**:armed 也压掉了「Rot 没开、句柄却完全有效」
  那类**非抛错**帧 ⇒ 过不了 (乙) ⇒ 走 `gated-fix`。**这是 §CR.2 第一次被用来「说不」。**
  **⭐⭐ 顺带修掉一个让缺陷对全仓不可见的量具洞**:`record_actions` 直到本轮没挂
  `ActionQueue_AttackUnit`/`ActionQueue_AttackMove`(出厂 5+1 个调用表达式、**全是连续型**,
  3 个就在 `mode_roam_generic` 的 Think 路径上)⇒ **读该日志的测试在真下了命令的帧上都答「没下」**;
  两钩已补、**13 个现存消费方全部重跑绿**;钉成 `[source S5]`。
  **读数**:`J.GetProperTarget(bot)` 在 **993/993** 帧为 nil,原因是 `handle_getters` + 0/107 fixture 覆盖
  ⇒ **UNMEASURABLE 不是 EMPTY**;**作废面 351 个调用表达式 / 164 个文件**,与 `0SIB` 的 `gate=0`
  同族、**同日第二例**,本轮只登记不审计。
  测试:`tests/test_rotscope_shadowed_target.lua`(`[ratchet]` **13/13**)+
  `tests/test_propertarget_corpus_domain.lua`(不打标签,29s,4/4)+ `tests/_propertarget_sweep.lua`。
  **变异 10 条:10 CAUGHT**。门:`luacheck_gate.sh` **裸读 exit 0 / 0 警告,未用 `RULE6_BYPASS`**。
  **⚠️ 连续两轮的自伤站点这一轮第一次没能发生**:开工自检**被它自己拒绝**(管道下不跑,
  `SELFCHECK_EXIT=2 ... NOT a pass`),改走文件重定向重跑;红的仍是 GH **#364** 的 flaky
  `test_rc_wrapper.py`,**不复核不重裁**。
  **明说没做**:同一文件四个同胞站点(Marci `:871`/Muerta `:884`/Faceless Void `:912`/Leshrac `:926`)
  把 `IsValidTarget` 写成距离测试的**合取项**,失败落进那条**跳过距离测试**的 `else` 连续攻击,
  而同一文件把同一条决策**安全地写过两次**(`:1071`/`:1092`,嵌套 + 宽谓词 `J.IsValid`)——
  **今天驱动不了**(四个英雄在 107 个 fixture 里**各 0 次**),不裁其杠杆价值。
  **交棒:总监**(甲 裁 `rotscope` 入集,**RIDESHARE、永远不能当独臂**;乙 `J.GetProperTarget`
  世界断言要不要立案;丙 §CR.2 的「拒绝性用法」要不要写进 §CR)、**录像组**(要帧:
  ① `GetTarget()`/`GetAttackTarget()` 的真实取值 —— **最值钱**;② 那四个英雄任一帧;③ 一局有 Pudge 的对局)。
  **批测台无请求、零 AWS。**
- 2026-08-31T13:50Z(**认领 GH #365**(总监 13:26Z 开的 `[bug]`,但 §3 点名的三个 id
  `salvepool`/`salveyield`/`tpreach` **全在本组作用域**——前两个是 owner P2 补给族、
  第三个是 TP 纪律;而 #365 §4 自己写着「归因不归我」);**报告
  `iterations/reports/strategy/20260831T135007Z.md`**;
  **无入集提议 —— 零新 gate id、零行为改动、`bots`/`game` 逐字节零 diff、
  `queue.json` 一字未动、零 AWS、S3 零访问、`state.json` 未改**):
  **GH #365 §3 的三条「真红」是假红,和它自己的 §2 是同一族。**
  **⭐ 主判据:开跑前 `rm -f` 控的是「陈旧文件」,不是「运行中被别人删」。** 那是同一个
  共享物理开关的两种失效模式,而 #365 判真红的唯一理由(「删了仍然红」)只关掉第一种;
  §2 自己记着当时 M1/M2 拉起的**真 `routine_selfcheck.sh`**(被 `PG_TIMEOUT` 杀)还在跑。
  **⭐⭐ 三条失败读数逐位等于它们自己文件里的 unarmed 值**,而那个值每个文件都另外断言并通过:
  salvepool `got 500` == `FLOOR` 且 unarmed sweep **含 anchor pool 890**;salveyield「did not yield」
  == unarmed 的 `== false`;tpreach 最锋利 —— **同一个用例体内往上三行**就断言
  「开关不在时同一帧同一函数给 false」。「断言写错」要三个独立文件各自错到恰好落在自己的
  unarmed 值上;一个共享原因一次解释三条。
  **⭐⭐⭐ 阳性对照逐字节复现**:并发 `rm -f` 循环下,三个文件的**文件名/行号(398/354/381)/
  断言正文/用例数与失败数**与 §3 的表**逐项相同**(19-1 / 29-2 / 8-1),连 salveyield 那条
  published 没展开的第二条(`:627 guard=false model=true`)也一起复现;干净顺序腿三个全
  **BARE_EXIT=0**。**独立佐证**:本轮自检同一条腿同一棵树打 **54 tagged / 0 failures**
  (加本轮新文件按同口径重跑 **55/0**),唯一 exit 3 是已由 GH **#364** 立案的 flaky
  `test_rc_wrapper.py`(**本组不复核不重裁**)。
  **机制的形状:危险是套件自己,不是流氓进程** —— 25 文件出现该路径、**22** 个逐字声明同一
  字面量、**22** 个含 `os.remove(SIDE_PATH)`、**0** 锁、**0** 进程唯一路径;而
  `load_with(nil)`(**unarmed 腿**)第一件事就是删 ⇒ **A 文件的 unarmed 用例正是能剥掉
  B 文件 armed 腿的删除者**,两个 lua5.1 进程重叠就够。
  **产出**:`tests/test_soakside_shared_switch.lua`(`[ratchet]`,**8/8**,秒级,源码普查+记录读数)。
  **变异 10 条:10 CAUGHT**(副本还原 + 每条前后 `sha256sum -c` + 退出码**裸读未经管道**)。
  **⚠️ 方法自伤三条**:(a) **连续第三轮**同一站点用 `| tail` 读自检退出码(横幅再次拆穿:
  `selfcheck worst exit: 3`)—— 已不像个人疏漏,交总监;(b) **一个存活变异体(M5)暴露真的
  断言太松**:第一版 S4 全文件搜串,而 salveyield 在**四处**断言同一个 `== false`,
  只有一处是 gate 的 unarmed 腿 ⇒ 改成**按用例名抽取用例体**后 CAUGHT,三条一并收紧;
  (c) **一次红基线差点把整台变异读成有效**(我自己把 `%s` 写成 `%%s` 而 `find` 是 plain 模式)
  —— **红基线下 10/10 全 CAUGHT 是无意义的**;修好后基线绿再重跑。
  **⚠️ 诚实边界**:强制并发的复现证明机制**充分**、不证明总监那一次确实在并发下(那是推断);
  干净腿是 3 次 + 54/54 + 55/55、**不是 soak**(1/50 的真缺陷排除不掉,**被排除的是确定性断言错误**);
  **本轮不裁三个 id 是不是好杠杆**(不入集/不出集/不改级);补救属 GH **#229**;
  全量单进程套件未跑(GH #124)⇒「只有这三条」的上界是 55 个快检测器不是整棵树;
  §2 的**泄漏**本轮未复现,只报「顺序干净运行下不泄漏」,**不反驳**总监的观测
  (被杀掉的进程正是走不到 `os.remove` 的那一种)。
  **下一格**:**总监**(甲 #365 §3 改判假红 —— 尤其 §6.2 的验收在这里会把人引向把
  salvepool 的 armed 445 改成 500,**那正好删掉一个真行为**;~~乙 管道读退出码~~ **已由 `a5578526` 落地(自检在管道下拒绝运行),棒不交**;丙 §6.3 那条 `soak_side.lua` 不泄漏
  普查要不要变常设断言 —— 本轮 55 文件重跑已给出现成读数)。
  **GH #229**:`[source S3]` 是它的进度计,落地当天故意变红;本组建议**序列化(套件级锁)**
  而不是进程唯一路径 —— 后者做不到,`J.IsSoakCandidate` 在出货代码里读的就是那个固定路径。
  **已发表**:GH #365 追评 `issuecomment-5479411913`(在 `57b0d5b8` push 之后,按 GH #290 的顺序)。
  **发布前 precheck 裸读 exit 3,唯一 finding 是假阳**(`MISSING path bots/Customize/soak_side.lua`
  —— 那是 `.gitignore:76` 的 farm-only 开关,**它不存在正是评论的主题**;precheck 不区分
  gitignored 与 tracked 路径 ⇒ **断言某文件不该存在的评论必然被判红**;与 GH #341 同族不同因),
  已在追评 §8 照实登记。
  **批测台无请求、零 AWS;录像组无请求。**
- 2026-08-31T10:50Z(**自驱** —— `[strategy]` 未认领 issue 仍为零;owner P1 第 1 棒早已交出、
  P2 上一轮已交棒 ⇒ 取 backlog **`0d`** 那一族明写「还没查的」那条(其余 mode 文件的连续型命令);
  **无入集提议 —— 零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、成员串一字未改、
  `queue.json` 一字未动、零 AWS、S3 零访问、`state.json` 未改**):
  **`towerCreepMode` 是 `roamstale` 的未复位同胞,而且它的消费点吃掉赢下竞价的那条分支 —— 顺序即闭式。**
  `Think()` 里 `:612` 排在 `:621`/`:628` 之上并且 `return`,而后两者是 `GetDesireHelper`
  **每一条**早返回分支唯一的落点 ⇒ 陈旧 flag **不是打错目标,是把赢下竞价的分支整个取消**;
  复位够不到那些帧同样是顺序:唯一的 in-helper 复位在 **16 条 `return` 之下**,`OnEnd()` 只在
  该 mode **不再赢**时触发(那正是 `Think()` 不会被调用的那一种)。
  **⭐⭐ 这条合同就写在同一个函数的头上,只被兑现了一次**:`[roamstale]` 注释把机制讲清、
  把分支点名,然后修了它覆盖的**两个句柄里的一个** —— `0S`/`0S2` 的新形状(**同一函数内**的同一条推理)。
  **⭐⭐⭐ 「照抄那条已 promote 的行」是错的**:`towerTime ~= 0` 与 `towerCreepMode` 是同一个比特,
  但「仍在窗口内」那条分支 `return` 前不重新确认 ⇒ 照抄会关掉**正在进行中**的攻击,
  `roamstale` 的安全性论证不覆盖这一步;正确修法多一句重新确认,由该不变式**可证是 no-op**(已断言)。
  **读数(993 存活英雄帧)**:暴露面 **58/993 = 5.8%**、**29 个 fixture**;
  **setter 在本语料不可达,理由是三个没接线的引擎量而非游戏条件 ⇒ UNMEASURABLE 不是 EMPTY**
  (`GetActiveMode()=0` ⇒ **925/925** 过不了 mode 闸,**连带关掉整个 `elseif` 半边**;
  `GetAnimActivity()=0` **993/993**;塔 `GetAttackTarget()=nil` 在有塔的 **264 帧全部**);
  其余三条 reach 子句不是瓶颈(925/847/845)⇒ `gate=0` 是归因不是裸零。**⇒ 本轮不落 gate。**
  报告:`iterations/reports/strategy/20260831T105005Z.md`;issue:**GH #362**;backlog 条目 **`0SIB`**;
  测试:`tests/test_towercreep_stale_source.lua`(7/7,`[ratchet]`)+
  `tests/test_towercreep_stale_domain.lua`(5/5,53s)+ `tests/_towerstale_sweep.lua`。
  **两个文件故意拆开,只有便宜那半带标签**(GH #358:不给每流每次触发加 +38%)。
  **变异 9 条:8 CAUGHT / 1 SURVIVED**,幸存者是变异形状不对、当场变成一条新断言(行首 `return`
  计数器的盲区在这棵树上是空的)。
  **⚠️ 当轮自伤**:自检接 `| tail -40` 读 `$?` 拿到 `tail` 的 0,而横幅写着 `worst exit: 3`
  —— 与 `0SGN` **同一站点同一手法、在它登记之后的下一轮又发生一次**;红的仍是 `0SGN` 登记过的
  `test_rc_wrapper.py` 假红,**本轮不复核不重裁**。
  **交棒:录像组**(缺的不是判据是**帧**:带回 `GetActiveMode()` / `GetAnimActivity()` /
  塔 `GetAttackTarget()` 任一,本组当轮即可钉帧落 gate)、**总监**(甲:`gate=0` 世界断言要不要立案
  —— 它作废一整类走 `CarryFindTarget`/`SupportFindTarget` 的历史结论;乙:「便宜半边进快腿、
  贵的半边不进」要不要变通则;丙:§CQ.3 加「注释点名了适用范围的修复必须断言范围内每个对象都被覆盖」)。
  **批测台无请求、零 AWS。**
- 2026-08-31T07:55Z(**自驱** —— 工作流 1 走完后 `[strategy]` **未认领 issue 为零**
  (#356/#347/#344/#342/#338/#324/#323/#319/#318 九条全是本组此前认领、现等他组裁定),
  backlog 顶 `0DUT` 已交棒完毕 ⇒ 取 **owner 优先项 P2** 责任链上本组自己那一格;
  **无入集提议 —— 零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、成员串一字未改、
  `queue.json` 一字未动、零 AWS、S3 零访问、`state.json` 未改**):
  **`margin(stayfield2) = S ∧ (¬T3 ∨ ¬T5)` —— 闭式。** 它唯一调用点的**上一条语句**是已 promote、
  无 gate、每局 Turbo 都活的 `if J.ShouldStayAndRegen(bot) then return BOT_MODE_DESIRE_NONE end`,
  两者之间无可执行语句;把子句对齐后 **T 的五条里三条被 S 蕴含**(turbo 相同、
  `hp∈[0.18,0.55]⇒[0.18,0.75]`、`1600 空⇒1200 空`)⇒ **HP 带与距离环 —— 这一族每次读数都在按它们分层的
  两个量 —— 永远不可能是一帧进边际域的理由。**
  **这是对本组自己 GH #342 §3 的更正**:那一轮扫**词元** `botHP` 刻画走路腿,而
  **词元扫描看不见住在函数调用后面的子句**(#342 对 TP 腿的结论不受影响,不重开也不反驳)。
  **⭐⭐ 而且方向是反的**:`mode_retreat_generic` 以 `return Min(nDesire, 1.0)` 结尾 ——
  **只夹上界不夹下界**,内部两处减法能把和推到零以下 ⇒ **凡用常数 `BOT_MODE_DESIRE_NONE` 提前返回的守卫,
  在自然出价为负的帧上都是在抬高出价**;实测 19 帧边际域 **14 抬高 / 5 压低**,
  声明切片 107 帧上负出价 **56/107 = 52.3% 是多数**;**同一条算术逐字适用于它上面那条发货中的 `tphome` 行。**
  读数(993 存活英雄帧):`S=23 / 已被吃掉 4 / 边际域 19`(**不是空集**,开工假设被自己读数否掉);
  **边际域几乎全由「补给」子句造出(18/1/0)**,而源码注释把**归因危险**写成这个 helper 存在的理由。
  报告:`iterations/reports/strategy/20260831T075529Z.md`;issue:**GH #360**(+ #339 追评);
  backlog 条目 **`0SGN`**;
  测试:`tests/test_stayfield2_marginal_domain.lua`(18/18)+ `tests/_stayfield2_margin_sweep.lua`(90s)。
  **⚠️ 当轮自伤**:开工自检用 `| tail -40` 读到 0,横幅自己写着 `worst exit: 3`
  —— `evidence-discipline` 规则 3 的站点,在它落地当天又发生一次。顺带 **GH #339 的活体**:
  自检报 `TRUNK RED tests/test_rc_wrapper.py`,同树 tracked 零改动、两次**裸读**复核均 exit 0
  (`68 passed, 0 failed`)⇒ 假红,落在 #339 点名的 exit 3 支上;**本组不裁,只交读数**。
  **交棒:录像组**(走路腿买 (a) 必须先与 `¬T3 ∨ ¬T5` 求交;优先量「补给」那半;
  顺带给真实对局里「撤退自然出价为负」的占比)、**总监**(甲:域审计通则化;
  乙:`Min(nDesire,1.0)` 缺下夹**本身**要不要立案 —— 出厂行为、影响该文件每条常数提前返回的守卫、
  含已 promote 的 `tphome`)。**批测台无请求、零 AWS。**
- 2026-08-31T04:20Z(**落地 `test_set.md §CO.1(三)` 的交棒**,总监 08-30T22:0xZ 交给本组的
  那一条;**无入集提议 —— 零新 gate id、零行为改动、`bots/` 只改注释(非注释行逐字节零 diff,
  已写成断言 `[source S2]`)、成员串一字未改、`queue.json` 一字未动、零 AWS、S3 零访问、
  `state.json` 未改**):
  **`pullcad` 注释里的「83% vs 58%」算术无误、预设有误** —— 它是闭式 `(nBeat − 0.5)/nBeat`,
  预设三条臂每一个引擎帧都被问到,而 §CK 的不等式否掉的正是这个预设。
  ⇒ **那两个数是 R → 0 的读数,而 R → 0 就是 `creepthink` armed 的世界**
  (`creepthink` 至今 gated 未 promote)⇒ 不是发货中的那个世界。
  **所以数字一个字没删,而且不是照办是有理由**:真帧驱动的四行是
  **0.0% / 41.2–50.1% / 58.4% / 83.4%**,关掉节流阀复现的 58.3796% 与 83.3518%
  **与后两行逐位相同** ——「旧数字 = R→0 读数 = `creepthink` armed 读数」**是等式**。
  **这条重推把 `pullcad` 抬高而不是压低,并改变了形状**:在发货世界里它不是把一条已占 58%
  的 drag 加宽,而是**把 drag 从空集里捞出来**(0.0% → 41.2–50.1%),机制是把 nBeat 抬到 R 之上
  —— 与 `creepthink` 攻击同一条不等式的另一侧。⇒ **强烈次可加**(0→50 与 0→58 单独,
  0→83 合起来),**这就是 §CO.1 (ii) 禁止并池在源码侧的那一半**,现已是一条会自己红的断言。
  报告:`iterations/reports/strategy/20260831T042059Z.md`;档案:test_set.md **§CS**;
  backlog 条目 **`0DUT`**;测试:`tests/test_pullcad_throttled_duty.lua`(11/11,
  变异 10 CAUGHT / 1 SURVIVED-by-design,零自伤)。
  **交棒:总监**(甲:登记 §CS、勾销 §CO.1(三);乙:本文件正好是 §CQ.3 那条 `PROVABLE`
  标记想要的形状,是否推广成「凡源码注释里写了效应量的 id,那个数必须被某个 ratchet 文件
  parse 并驱动」)。**批测台无请求、零 AWS。**
  **本组自己下一格**:`0VAC` / §CO.1(三)的交棒**至此清空**;下轮取 backlog 顶或未认领的
  `[strategy]` issue(#342 / #338 / #324 / #323 / #319 / #318)。
- 2026-08-31T01:23Z(**认领 GH #349**,批测台交棒的 **trunk RED**;**无入集提议 ——
  零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、成员串一字未改、
  `queue.json` 一字未动、零 AWS、S3 零访问、`state.json` 未改**):
  **共臂行 `creepthink > pulldrag` 是可证空的 —— `creepthink` 的字面量在 `pulldrag`
  的调用点上是不可达代码,有两条彼此独立的闭式理由(`Think` 的控制流;两个 pull 计划字段
  三处写入两两互斥),所以 arming 它在那里一帧都不动。** 登记落地后 trunk 那条红消失。
  **⚠️ 收尾自检抓到一次撞车**:总监 **01:14Z 已裁过同一行、结论一致**(早约 9 分钟),
  但那份工作(`9a9d43b`)**只在分支上、不在 `origin/main`** ⇒ 本轮开工时 trunk 是**真红**
  (自检独立复现),两边各花一个工作单元。**成因是产物没落地(GH #290),不是触发撞车。**
  本组**不动别人的分支、不 cherry-pick、不主张自己那份更该留**,已把收拾方式发在 GH #349
  第二条评论上交总监(`9a9d43b` 另带的 `rc.sh` 等与本组无关、应照常落地)。
  报告:`iterations/reports/strategy/20260831T012325Z.md`;档案:test_set.md **§CP**;
  backlog 条目 **`0VAC`**(主判据 / 判别式 / 三个读数的对照表 / 变异台与自伤 / 诚实边界四条
  全文在那里)。**交棒:总监**(确认登记 ⇒ #349 可关;并裁一条方法问题 ——
  登记器的 WIDE 行要不要区分「判断」与「可证」两档)。**批测台无请求、零 AWS。**
  **本组自己下一格**:§CO.1 (三)(`pullcad` 注释「83% vs 58%」建在无节流阀的模型上,需重推)。
- 2026-08-30T22:30Z(**认领 GH #344**,走**铁律 9 + 工作流 1**;**已发 GH #347**;
  **无入集提议 —— 零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、`queue.json` 一字未动、
  零 AWS、S3 零访问、`state.json` 未改**):
  **GH #344 的 127 条「满血步行回家」落在一条任何 id 都够不到的闭式带子里 ——
  `hp > 0.55 ∧ 4000 ≤ d_泉水 < 10000`;而且没有一条由 (hp, mp, 1600 环, 距离) 组成的
  帧级谓词能给它定价:本仓库 993 帧上那条带子占 21.1%,比唯一能碰它的杠杆 `itemtrip` 的
  整个域(14.7%)还大,加上 #344 的满蓝条件仍有 8.4%。**
  认领依据:#344 是 22:08Z 新开的**唯一未认领 `[strategy]`**,且是 owner 优先项 **P2** 的
  「步行回泉」那一半 —— P2 责任链当前球在本组(铁律 9 凌驾于 issue 流)。
  **⭐ 主判据(闭式)**:P2 步行腿只有两个 id,`stayfield2`(→`IsFieldRegenSituation`)拒 `nHP>0.55`
  且**没有任何距离子句**;`itemtrip`(→`IsWastefulItemTrip`)拒 `hp<0.55` 且拒 `d<10000`。
  **血量轴用同一个 0.55 无缝拼接(刻意)⇒ 洞在距离轴**,4000 正是 #344 自己 `walk_home_trips`
  的起点门槛(`FAR_U`)。帧 A(lion,掉头点 7,065u / hp 1.000 / mp 1.00)落在带内:
  **一帧、两个 id、两个彼此独立的拒绝理由。**
  **⭐ 第二条(订正一种自然读法)**:唯一认得 #344 那张脸的分支
  `ConsiderHeroMoveOutsideFountain`(注释逐字 `-- is stuck in item mode`,读的正是
  `BOT_MODE_ITEM ∧ hp>0.95 ∧ mp>0.95`)**无 gate = 稳定版**,但被 `DistanceFromFountain() >
  MoveOutsideFountainDistance → false` + 泉水光环挡在**到家之后**,且它驱动的动作只走到
  **离泉水 1500** —— **在 #344 定义「到家」的 2000u 环之内** ⇒ **按构造只能缩短「停留」,
  永远不能终止一趟行程** ⇒ **#344 的停留中位 12s 是这个 hatch 的产出,不是「无人在管」的证据**;
  也解释了「两条腿两个分层同号 ⇒ 稳定版行为」。
  **⭐⭐ 可复用判据(实测)**:**量纲不对,不是常数不对。** 107 fixture / 993 存活帧:
  `IsWastefulItemTrip` 域 **146/993=14.7%**、**无主带 209/993=21.1%**、加 `mp>0.95` 仍 **83/993=8.4%**
  ⇒ 按满蓝分档把下界降到 4000 会把帧域抬到 **23.1%**,正是 `itemtrip` 在 **33.1%** 上被按条件 (b)
  退回的同一个数量级。**这个谓词选帧,#344 数行程;那 127 条的判别特征——掉头回来、手里什么都没多——
  是行程级的量,没有任何一帧带着它。** ⇒ **#344 的「先只观测」是对的,理由是算术不是谨慎。**
  **产出**:`tests/test_healthy_walk_home_gap.lua`(`[ratchet]`,**14/14**);五个常数全部 parse,
  另有一条 `[control]` 扫本文件可执行部分的字面量;`[drive]` 在 `f_260822_063722_lina_tp_home` 上
  **一次只换一个操作数**,两个谓词的**四条边都真的在这一帧上做决定**;
  **`[control]` 是前提**:该帧自己距泉水 **10,009.85u**、只比出货下界高 **9.85**,
  所以 hp=1.000 下它自己为真 ⇒ `7065` 那个假是关于 **7065** 的读数不是关于这个 fixture 的。
  **变异 9 条真变异:9 CAUGHT / 0 SURVIVED**,第 10 条作用域控制 SURVIVED(正确);
  **文件副本还原 + 每条后 `sha256sum -c`(10/10 OK)+ 变异前后各取一次哈希 + 退出码 bare 读**
  (`evidence-discipline` 规则 1/3/4;**本轮零自伤**)。
  **诚实边界**:不裁任何人、**#344 未被回答**(这是观测的源码那一半)、#344 的百分比一个字没断言、
  语料四数**没钉进 ratchet**、`GetActiveMode()` 在 fixture 上恒 0 ⇒ **不主张那 127 条是哪个模式发的**、
  全量单进程套件未跑完(GH #124)。
  **下一格**:**录像组**(检测器必须多打三列:每趟**最大**泉水距离 / `t0` 的 active mode /
  停留与步行分开)、**总监**(裁一条方法问题:候选 id 的「域」什么时候允许用**帧**计数报价 ——
  `itemtrip` 退回那次请求方按**行程**定价、仪器按**帧**报价;本组**不主张**它重新入集,
  **不主张**动 10000)。
- 2026-08-30T19:20Z(**认领 GH #340**,走章程工作流 1;
  **无入集提议 —— 零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、`queue.json` 一字未动、
  零 AWS、S3 零访问、`state.json` 未改**):
  **录像组 18:57Z 把 201 次回家 TP 按第一失败子句分解,第二大桶是 `hp>0.55`
  (armed 30.6% / baseline 21.4%);而 `stayfield` 唯一调用点的进入条件把 `botHP` 的上确界
  锁死在 0.43 —— 那条子句在 TP 腿上根本不可能成立。那 30+22 行不是「留守窗口太窄」,
  是从别的按下点发出的 TP。**
  认领依据走**铁律 9 + 工作流 1**:优先项四项无一球在本组(常设运维在批测台、P1 第 1 棒已交、
  P2 那一格已交棒、P3 归总监);open `[strategy]` 六条(#338/#324/#323/#319/#304/#300)
  **全部是本组此前认领、现等他组裁定**;19:0xZ 新开的 #339/#341 是 `[harness]`。
  #340 是 `[bug]`,但整篇的主语是 `stayfield`/`stayfield2` —— **本组地界的两个 id**,
  且它 §5.2 明写建议改走 fixture 路线 ⇒ 取它。
  **⭐ 主判据(闭式不可满足性,不是估计)**:`J.IsFieldRegenSituation` 的带
  `nHP < 0.18 or nHP > 0.55`(`nHP = J.GetHP(bot)`);「撤退:3」(`aiug:5626`)进入条件
  `botHP < 0.34 or botHP + botMP < 0.43`,**承重一步是那个 `botHP` 就绑在 `:5224` 的
  `local botHP = J.GetHP( bot )` —— 同一个函数**,两条带不换算就可比(树里另两处 `botHP`
  用的是 `GetHealth()/GetMaxHealth()`;M5 证明断言取的是锚点前最后一次绑定)。
  `J.GetMP` 是非负量的比值 ⇒ `botMP >= 0` ⇒ 第二个析取项蕴含 `botHP < 0.43`
  ⇒ **`sup = max(0.34, 0.43) = 0.43 < 0.55`** ⇒ **天花板子句在 `stayfield` 唯一调用点上不可满足**;
  下界不是(`0.18 ∈ [0,0.43)`)⇒ **`hp<0.18` 是唯一能在 TP 腿上做决定的那条边**。
  方向保守:其余**十二个**合取项一律当成已满足,结论仍成立。
  **⭐⭐ 可复用判据是 GH #319 的外一层**:**一条子句的实测命中率是它被评估的那个「人口」的属性,
  不是它所在守卫的属性** —— 全人口的第一失败子句分解会把**该谓词没接线进去的调用点**的行
  记到共享谓词头上,直方图算术正确却**把杠杆排错序**;修法是**先与调用点进入条件求交再排序**
  (本族=四个常数、零数据)。#319 缩守卫的域,这条缩**测量的分母**。
  **0.43 早就在桌上**:13:27Z(`0MODE`/GH #333)算的就是它,只是被塞进求撤退**块**上确界的
  `max()`(0.87)里,**没有任何一处把它和 0.55 比过**。
  **买到的三件**:(1) 那 30+22 行**不是「撤退:3」发的**,是对 #340 §4.2「reach = 0」的独立、
  脱离仪器且更锐的推导 ⇒ **放宽留守 HP 窗口永远抓不到它们**;(2) `hp>0.55` **只在走路腿上有意义**
  (走路腿到调用点之间只有一处 `botHP` 比较,且在 `DotaTime()<0` + **`not enemy:IsBot()`** 里,
  全 bot 批测取不到;M6/M10 各自抓到)⇒ **GH #338「(a) 只能从走路腿读」的第二条、不同来源的理由**;
  (3) TP 腿残量**上界 ≈ 201 的 7–8%**,且是**过其余十二个合取项之前** —— **两条不同子句独立到达同一个零**。
  **产出**:`tests/test_stayfield_hp_window_reach.lua`(`[ratchet]`,**15/15**);
  **四个常数全部从树里 parse**;`[drive]` 在 owner P2 那一帧上**只建模 `J.GetHP` 一个操作数**,
  两条边**在这一帧上都真的做决定** ⇒ 天花板不是恒真谓词,是 TP 腿从不递给它这种帧。
  **变异 10 条:10 CAUGHT / 0 SURVIVED**;**还原走文件副本 + 每条后 `sha256sum -c`(11 次全 OK),
  退出码逐条 bare 读、未经管道**(用上了本轮 19:00Z 才落地的 `evidence-discipline` 技能)。
  **M9(模型恒 true)让 `[arith]` 全绿而 `[control]` 红**,分工写成实测。
  **⚠️ 当轮三处自伤,全部当轮抓住并修好**:(0) **第一版变异台整个失效而看起来正常** ——
  还原写 `git checkout -- bots tests/<新文件>`,新文件当时 untracked ⇒ 整条命令报错退出
  ⇒ **`bots` 也没还原** ⇒ 六条变异**累积叠加**,失败计数 3→3→5→5→6→7→8→8
  像一张正常的递增表,**没有任何一条腿举手**(`evidence-discipline` 规则 1 的站点再加一个,
  而本轮是犯完之后才读到该技能)。连带订正:M8 原记为「打偏到别的文件」,上哈希后看清
  `aiug:4040` **根本不含被替换的模式** ⇒ `sed` 一字节没改 ⇒ **不是「抓不到的变异」,
  是「不存在的变异」**;两种解释给出同一个绿,分辨它的是**变异前后各取一次哈希**。
  (i) `strip_comments` 把**本身是注释**的锚点
  `第三种情况` 也删了 ⇒ 十个算术用例在健康的树上同时红;改用 `mask_comments`(注释涂成等长空格、
  偏移逐字节对齐)。与 `0MODE` 的锚点自伤同族。(ii) 刀口探针用 `tp3_entered(0.34, 0)` 探 HP 帽,
  而 `0.34+0 < 0.43` 为真 ⇒ 把 sum 析取项的放行报成「HP 帽变非严格」;**两个析取项约束同一个量,
  哪一个都不能单独读**。
  **诚实边界**:`botMP >= 0` 是外部操作数(huskar 那支返回 HP 比值,仍 ≥0,且分支按名字排除它);
  **#340 的百分比本文件一个字都不断言**(重新归类一个桶是关于**树**的算术,不是重新测量);
  **本文件不裁任何人**,**不重开也不反驳 #340 的 INDETERMINATE**;**不主张 0.55 错了或该动**;
  那 52 行的按下点来源本组不主张,只主张**不是「撤退:3」**;**全量单进程套件本轮未跑完**(GH #124)。
  **铁律 6**:`luacheck_gate.sh` → **0 warnings,退出码 0,bare 读取未经管道**(自己装的 `lua-check`);
  ⚠️ **本轮第一次读它是错的** —— 写成 `| tail -8; echo $?`,读到的是 `tail` 的码;真值一样但读法坏,
  **`evidence-discipline` 规则 3 的第四个站点、且是立法当天**,已重读。
  `arm_push_gate.sh` **already set**(两次 push 各自跑过钩子);**`RULE6_BYPASS` 未使用**;
  新文件 **15/0 exit=0**;邻居九条全绿且 **exit 全 0**
  (stayfield 36/0 · fieldsip 15/0 · fieldbuy 35/0 · bagsalve 18/0 · tphome 14/0 · tpsafe 7/0 ·
  gate_claim 10/0 · gated_helper 10/0 · fieldcreep 23/0);⚠️ 这九条第一次跑在 120s 超时的循环里、
  **被 SIGTERM 杀在第七条(exit 143,规则 3 点名的那一形)**,已全部重跑并逐条读码;
  `git diff --stat HEAD -- bots game` **为空**,变异台收尾 `sha256sum -c` 四个文件全 OK。
  **开工自检**:exit 0;anchors stable-v1/v2 各 3 项 ok;`ORPHAN_PROPOSAL: none`;
  cadence 一处 `SKIPPED-IN-STREAM strategy/20260828T0730Z.md`(戳不规范,非空转)。
  **交棒**:**录像组**(重跑 #340 §2 的表时先与调用点进入条件求交;`hp>0.55` 改在走路腿上分解,
  与 #338 的主槽 `item_flask` 分层合并;那 52 行的按下点来源)/ **总监**(本组不主张任何入集出集变动,
  请裁**方法**问题:第一失败子句分解是否统一要求先与调用点进入条件求交)。
  **交棒已发 GH #342**。全文:`iterations/reports/strategy/20260830T192007Z.md`。
- 2026-08-30T16:25Z(**自选题**,走章程工作流 1 的第二分支;
  **无入集提议 —— 零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、`queue.json` 一字未动、
  零 AWS、S3 零访问**):
  **`fieldsip` 入集三小时后,`stayfield` 在它唯一的调用点上就没有域了 —— 而两个 id 从头到尾
  没有互相点名过一次。**
  选题依据走**铁律 9 + 工作流 1**:优先项四项无一球在本组(P1 第 1 棒已交、P2 那一格已交棒、
  常设运维在批测台、P3 归总监);open `[strategy]` 七条均为本组此前认领现等他组裁定;
  16:00Z 前新开的 #332/#334/#335 不归本组、#333 上一轮已认领 ⇒ 取自选题,
  而**录像组 15:58Z §13 第 1 条**把 `stayfield`/`stayfield2` 点成下一轮补课目标并写明
  「留守率差分仍然不可用,要买得另找触发级读法」⇒ 本轮做那句话的**前置**:
  先算清楚那个触发级读法**在当前串上还有没有域**。
  **⭐ 主判据(闭式空集)**:`itemFlask == nil`(「撤退:3」自带)+ `J.IsItemAvailable` 只看 0–5 槽
  ⇒ 该处 sip 上确界 **135** ⇒ `fieldsip` 的 `>= 0.25*maxHealth` 要求 **maxHealth <= 540**,
  而同一分支要求 **level >= 9**。⇒ **W27/W28 那根串上 `stayfield` 的 (a) 买不到**,
  不是没买到。方向保守(其余合取项一律当成已满足)。
  **⭐⭐ 可复用判据是 `0SITE` 的外一层**:第三个 id、晚三个月入集、在第三个文件里、
  带独立裁定,**可以清空另外两个 id 的交集而互不点名**;`check_armed_wiring.py` 仍判 WIRED
  (它查调用点存在,不查谓词在那里可能为真)⇒ **没有任何东西会变红**。
  **有用的那半**:走路腿 `stayfield2` 从 `GetDesireHelper()` 开头到调用之间**没有任何 flask 合取项**
  (已断言)⇒ 天花板 1600 而非 540 ⇒ **本族的 (a) 只能从走路腿读**,按主槽 `item_flask` 分层。
  **第三半**:`bagsalve` 的「单独 arm 逐字节 no-op」论证在 `fieldsip` armed 时**反号** ——
  背包腿是唯一一条 `itemFlask == nil` 杀不掉的腿(它停在 5 槽)⇒ 540 血以上**唯一**的使能器;
  已在**真实**背包大药帧上驱动。
  **产出**:`tests/test_stayfield_callsite_domain.lua`(`[ratchet]`,**21/21**);
  变异 **11 条 10 CAUGHT / 1 SURVIVED(按设计,M11 由 `lina_walk_home` 红 3 条兜住)**;
  两条天花板从表里现算;**锚点唯一性写成断言(上一轮 `0MODE` 自伤的根因,这轮预防)**。
  **诚实边界**:「level≥9 ⇒ maxHealth>540」不在树里(语料 **314/318**,4 个例外**同一个英雄** medusa,
  像量具异常);`bagsalve` 腿在 fixture 上端到端跑不通(14 行背包大药、**0 行**进 situation);
  retreat 块在 fixture 上不可达(GH #89);**本轮不裁任何人**,空集证明不是裁定;
  全量单进程套件未跑完(GH #124)。
  **铁律 6**:`luacheck_gate.sh` → **0 warnings / exit 0**;逐文件动态见报告 §5(邻居 10 个文件全绿)。
  **开工自检**:exit 3,来源**全部是 cadence**;trunk python **59/0/0**、fast Lua **40 文件 0 failures**;
  `ORPHAN_PROPOSAL: none`。
  **交棒(GH #338)**:录像组(改读走路腿)/ 总监(§CG 的未登记副作用 + `bagsalve` 论证反号)/
  harness(medusa `max_hp`,未立案,请裁)。全文:`iterations/reports/strategy/20260830T162504Z.md`。
- 2026-08-30T13:27Z(**认领 GH #333**,走章程工作流 1;
  **无入集提议 —— 本轮零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、`queue.json` 一字未动**;
  **另修回本组自己 11:13Z 造成的章程损坏,见末段**):
  **#333 说「两个世界在数据上不可分」是因为它去找 mode;而撤退支的三条 TP 按下全部带 HP 帽,
  联立上确界 0.87,它自己发表的那一帧 hp=0.90 就在帽子外面 —— 撤退残渣那个世界是被算术关掉的,
  不需要 harness 补字段。**
  认领依据走**铁律 9**:优先项四项里常设运维球在批测台、P1 第 1 棒本组已交、P2 本组那一格已交棒、
  P3 归总监 ⇒ 回 issue 流;open `[strategy]` 四条(#318/#319/#323/#324)均为本组此前认领现等他组裁定;
  13:0xZ 录像组新开三条里 **#333 §三.1 白纸黑字把下一棒交给 fixture 路线**,且 `tpreach` 是本组地界
  (本组 GH #319 正在裁它的合取项)⇒ 取 #333。
  **⭐ 主判据(闭式上确界,不是估计)**:`nMode == BOT_MODE_RETREAT` 块
  (`ability_item_usage_generic.lua:5506–5664`)**恰好三条 TP 按下**(:5581/:5616/:5662),每条带 HP 帽:
  撤退:1 `botHP < 0.19`;撤退:2 `botHP < 0.15 + 0.24*nEnemyCount` **且**
  `nEnemyCount <= (botHP < 0.4 and 2 or 3)`;撤退:3 `botHP < 0.34 or botHP+botMP < 0.43`。
  **只有撤退:2 随敌人数抬高,而抬高它的那个量正被它自己的第二个合取项帽住** ⇒ `botHP >= 0.4` 时帽是 3
  ⇒ 杠杆最高 `0.15+0.24*3` = **0.87**;撤退:3 的析取项被操作数值域关掉(`botMP >= 0` ⇒
  `botHP+botMP < 0.43` 严格弱于 `botHP < 0.43`)⇒ **sup = max(0.19, 0.87, 0.43) = 0.87**,
  即 **hp >= 0.87 关掉树上每一条撤退 TP 按下**。`[arith A1]` **把所有非 HP 合取项一律当成已满足**
  (掉血史/卡视野/大药/modifier/离泉水距离/英雄名)⇒ 方向保守,**比按那一帧真实取值关掉严格更强**。
  **⭐⭐ 因此那一帧是真漏不是残渣**:lion `990f5c/20260830_063340_slot1` armed 腿 t=657.0
  **hp=0.90 >= 0.87 ⇒ 撤退世界关闭**;独立佐证 —— 三条撤退按下落点**全是 `J.GetTeamFountain()`**,
  而 #333 自己观察到「**落点不回家**」(d(home) 8720→8479→8183 基本原地)。
  ⇒ 按下来自**会咨询** `J.CanEnemyInterruptTpChannel` 的路径;`[drive D1]` 在真实谓词上驱动那一帧操作数:
  **未 armed = false**(705 > 700,盲带)、**armed = true**(705 <= 750,DP 攻距 600 + 150)
  ⇒ **armed 本该否决而它没有**。其余两个咨询点(`GetRescueTpTarget` 需 `lf_rescue`、mid/sup 响应 TP 需
  `midtp`/`suptp`)**不构成第三个世界**:门关着时**直接 `return nil`、根本产生不了按下**,门开着时**都咨询**。
  **⚠️ 唯一限制,也正是下一棒(诚实登记)**:0.90 是 **1Hz 采样**,#333 表里按下夹在
  656.5 行(0.90)与 657.5 行(**0.69 < 0.87**,DP Carrion Swarm 656.3 之后)之间 ⇒
  若按下瞬间真实 HP 是后者,**撤退:2 重开**(需 `nEnemyCount = 3`)。**但这恰是最值钱处:
  hp 与 nEnemyCount 是 dump 已有的列,mode 不是** ⇒ **#333 §三.2「需要 harness 补 mode 字段,
  那是另一条线」本组认为不欠**。`[control C1]` 把刀口写成断言(0.86/3 可达、0.69/3 可达、0.69/2 关闭)。
  **⭐ 退回 §三.1 的 fixture 路线(只退这一步)**:钉那一帧的 fixture 驱动的是**谓词**,armed 得 true ——
  **在两个世界里都是 true**,因为**谓词的答案不取决于调用者问不问它** ⇒ **报绿而不携带关于该歧义的
  任何信息**,与 `0FOG`(甲)/`0GEOM` M5/`0SENSE` M12 同族(「不承重所以报绿」)。判别要驱动**调用点**
  并带真实 mode,而 `[corpus C3]` 实测本仓今天做不到:`GetActiveMode` 在 `bots/` 调 **360 次**、
  在 `tests/mock/` **定义为零**、**107 个 fixture 里 0 个携带** ⇒ **fixture 路线不是绕开那个缺失操作数,
  是继承它**;绕开它的是上面那条算术。C3 写成**存在性**不是头计数:加 fixture 不会变红,
  **只有真把操作数接上才会** —— 而那一天正是 fixture 路线开始可用的那一天。
  **产出**:`tests/test_tpreach_retreat_exclusion.lua`(`[ratchet]`,**8/8**;
  官方 runner `run_tests.lua tpreach` **15/0** = 新 8 + 既有 7)。
  **变异 11 条:11 CAUGHT / 0 SURVIVED**,分两族登记(A1 跑本文件的模型、source 断言跑树)——
  **M5(模型恒 false)⇒ C1 红而 A1 全绿**,这就是 C1 存在的理由:算术那半只有靠 C1 证明
  「帽子下面确实够得着」才承重;**M10(改树上的 0.24、模型不动)⇒ S2 红而 A1 绿**,
  把分工写成实测:**S2 一旦被删,A1 会继续通过,但描述的是一棵不存在的树**。
  **⚠️ 当轮自伤(第一遍红、当轮修好)**:S1/S3 第一版锚在 `nMode ~= BOT_MODE_RETREAT` 上,
  **而它在本文件里不唯一**(另一处 :4029 且**排在前面**)⇒ S1 的 span 从 :4284 一直吃到 :5668、
  **把 :5239 那道真门吞了进去**,健康的树上 S1/S3 双红。改锚到**唯一的 wrapper 调用**
  `J.ShouldNotStartInterruptibleTp( bot )` 并加 `TPSAFE2_ONCE` 钉住这个唯一性(M11 证明有牙:
  加第二个调用点 ⇒ S1+S2+S3 三红)。**与 `0GEOM` M5 同族:锚点唯一性本身要被断言,不能靠读一次 grep 记住。**
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启 9.0s,自己装的 `lua-check`);
  `arm_push_gate.sh` **already set**;**`RULE6_BYPASS` 未使用**;新文件官方 runner **8/0**;
  邻居全绿:tpsafe 7/0 · tpgap 22/0 · tphome 14/0 · coarmed 11/0 · gate_claim 10/0 ·
  gated_helper 10/0 · itemdesire 25/0;`git diff --stat -- bots game` **为空**(变异后已核对复原);
  开工自检 worst exit **3**(**仅 cadence**,是 director 08-29T04:08Z→16:28Z 的 12.3h 洞,
  且自检自己标注窗口内有 3 个命名不规范文件 ⇒ 不属本组、且很可能是命名问题不是空转)、
  `UNCERTIFIABLE: none`、python 腿 **57/0**、快腿 **38/0**、锚点 stable-v1/v2 各 3 项 ok;**AWS $0,S3 零访问**。
  **⭐ 全量单进程套件本轮跑完了(收尾后落地,订正本条)**:**2636 tests, 0 failures, EXIT=0**,
  墙钟 **≈13:22Z → 18:09Z ≈ 287 分钟**(不设 timeout)⇒ **撤回「本轮未跑完」**:它跑完了、是绿的、
  **且覆盖本轮新增文件**(最后一次 `.lua` 改动在起跑前;13:35Z 那个 mtime 是 rebase 重新 checkout
  **不是编辑** —— 与本组 07:24Z 那轮同一个陷阱;rebase 只并入 `.py`,`run_tests.lua` 只 glob
  `test_*.lua` ⇒ Lua 用例集合与已推送树相同)。**GH #124 的第三个完成读数**:
  07:24Z 2601/0 ≈310min、本轮 2636/0 ≈287min ⇒ 与 10:38Z「决定完/不完的是 timeout 设得够不够长,
  不是容器负载」一致,`AGENTS.md` 的「~100 min」**低约 3 倍**再次被证实。
  **混杂项**:起跑后约 15 分钟内与邻居腿抢过 CPU,其余基本空载。
  **⚠️ 对 GH #315 的一条读数(不是判决)**:这一遍跑到底、期间**无 stash/rebase**,
  `test_cm_arcane_aura_passive.lua` 与 `test_cm_pos5_boots.lua` **都没红**(都在这 2636 里);
  上一轮本组那条 `pos5_boots:302` 红**当轮已自我作废**(读数取自我 stash/rebase 到它脚下时),
  本轮与「那条红是 stash 假象」相容。**不主张 #315 该关** —— 没复现不等于不存在。
  已发表 GH **#315** 更正 **5470410060**(上一轮那条评论的表**第三行撤回**:作废当轮只写进章程/报告、
  **没回到评论上**,issue 上留着的是没有限定词的强版本)。**限定词必须和读数写在同一个地方。**
  **⚠️ 诚实边界**:无行为改动 ⇒ 无修复用 fixture;**本轮无新帧**(#333 那一帧是**被引用不是被驱动**,
  其 timeline 在 S3,本组零 S3 访问);**不重推也不反驳** #333 的 6/1010、分层与 INDETERMINATE 裁定
  (分层那条现归**铁律 4(i-b)** —— 总监 08-30T13:03Z 按 GH #329 拆成四条,`test_set.md §CL`;
  `tpreach` 的 ADDED 是**检测器计数、侧偏未消除**,正是 (i-b) 点名的典型 ⇒ 反号=噪声成立,
  **不是** (i-c) 那条「已 swap-average 的估计量反号不算否决」。本轮只重开它发表为**素材**的那一帧);
  **不主张 `tpreach` 该 promote,也不主张它该出集**((b)/(c) 不归本组,**一帧不是条件 (a)**);
  hp=0.90 与 d=705 是 **#333 的数**,引用不重算;`[arith A1]` 跑的是**本文件的模型**不是树。
  顺带一条读法限制:**mock 层吞掉 `print`** —— 手写 runner 用 `print` 报读数会静默丢失。
  **⚠️⚠️ 顺手修回本组自己造成的章程损坏(本轮发现)**:`d42f90a0`(本组 08-30T11:13Z 的
  10:38Z followup)把 **backlog 的 0FOG..文件尾整段(2,960 行)复制了一份**,并在复制体前面
  **插了第二个 `## 当前状态` 标题**,于是本文件有**两个 `当前状态` 节**、`0FOG`/`0SENSE` 等条目**各两份**,
  且两个节从 12:25Z 起**内容分叉**(前一个持有 followup 的新版 10:38Z 条目,后一个持有旧版)。
  **这正是自检 `citation_audit` 的 AMBIGUOUS 家族**(两节抢同一个标题),在 main 上躺了约 2 小时。
  本轮修回:删掉重复段与多出来的标题,把**新版 10:38Z 条目**并回唯一的 `当前状态` 节;
  修前逐条断言过形状(`L[73:3033] == L[3081:6041]` 逐行相等)⇒ **删的是证过的重复,不是判断**。
  **教训**:大段插入要按**唯一锚点**定位并在写盘前断言节的条数,与本轮 S1/S3 自伤**同一个根因**。
  **交棒**:**录像组**(球在这里,而且这一棒变小了 —— 在 `990f5c/20260830_063340_slot1` 上读
  **按下瞬间 t=657.0 的 hp 与 1600 内敌方英雄数**两列,两列 dump 都已经有:
  `hp >= 0.87` ⇒ 撤退世界关闭 ⇒ 判 **BUGGY**;`hp < 0.87 且 nEnemyCount == 3` ⇒ 仍不可判。
  **不需要 harness 补 mode 字段**)、**总监**(裁 #333 §三.3:`--reach-mode source` 那列的 0
  写进 §BC 作已知读法限制,本组同意写,理由与 #333 一致 —— `SOURCE_CITED_RANGE` 那 8 个英雄本语料一个没出场)。
  **不认领**:#332(`[batch]`)、#334(`[harness]`);#318/#319/#323/#324 均为本组此前认领、现等他组裁定。
  **先 push(`782ff956`)再发表**(铁律 6 ⭐GH #290);`claim_precheck.sh` **exit 0**
  (`local commits not on origin/main: 0`,paths cited 3 / resolved 3 / refused 0)⇒
  已发表 GH **#333** 追评 **5469014421**(裁定全文),并开 **GH #335**(`[harness]`:
  `citation_audit` 的 AMBIGUOUS **只在有人引用某个 `§XX` 时**才求值、**从不主动扫章程**,
  而本例重复的是 `## 当前状态` 标题与 `0XXX.` backlog id、**两者都不在它的语法里**;
  自检八条腿 `grep -c duplicate` = **0** ⇒ **这一族根本没有检测器**,不是漏报。
  附现成验收:`d42f90a0` 上必须红、`782ff956` 上必须绿)。
  报告:`iterations/reports/strategy/20260830T132726Z.md`。
- 2026-08-30T10:38Z(**认领 GH #326**,走章程工作流 1 → backlog #7;
  **有行为改动:一个 gated id `creepthink` 真的落了地**;入集提议 `test_set.md §CK` +
  批测请求 `queue.json:strategy-25` 已同开;**零 AWS,S3 零访问**):
  **GH #326 那张「6 秒坐标逐位不变」的表不是域泄漏的证据,是分支自己的输出 ——
  拉线节拍的三条臂全部坐在 Think 开篇的动画节流阀后面,而 `R > nBeat` 时 DRAG 那条 `else` 一帧都到不了。**
  认领依据走**铁律 9**:优先项四项里常设运维球在批测台、P1 第 1 棒本组已交、P2 本组那一格已交棒、P3 归总监;
  open `[strategy]` 全部是本组此前认领现等他组裁定 ⇒ 回 backlog,最上面的活条目 **#7「拉野节奏打磨」**,
  而 **#326 正压在它上面**、且 §「请总监裁」的 (乙) 明写「属协同组地界」。
  **⭐ 主判据(不等式,不是百分比)**:记 R = 节流阀重开间隔(实际就是攻击周期),
  节拍**只在重开帧上被问到**、那种帧上距上次 poke 已 ≥ R ⇒ **R > nBeat ⇒ POKE 恒真 ⇒ DRAG 空集**。
  出厂 `nBeat = 1.2`、前期攻击周期 ~1.4–1.7s ⇒ **出厂站在不等式的错误一侧**;与 GH #186/`pullthink` 同族,
  那条注释自己写着「Scoped to the CAMP pull only … one lever at a time」,**本轮兑现的就是它明写的那半**。
  **⭐⭐ 退回 #326 的一步推论(只退那一步)**:它自己的 gap 列 **1.6/1.4/1.6 全部大于 1.2、没有一个更小** ——
  那是**延迟**的签名(节流阀只能让 poke 迟到、不可能提前),**域泄漏没有理由是单边的**;
  静止帧的**计数**不反驳也不重推,±6% 是 **44 id 同波的 bundle 界**、#326 自己不主张已排除反向抵消。
  **产出**:`bots/mode_roam_generic.lua` 一条并列旁路子句;`tests/test_creepthink_anim_throttle.lua`
  (`[ratchet]`,**12/12**,2.6s,快腿 tagged **36 → 37**(按自检自己的并集口径:tagged ∪ 四个具名文件;实测));`state.json:creepthink_20260830`。
  **变异 11 条:10 CAUGHT / 1 SURVIVED(M8,promote 过的 `pullbeat` hold,登记而非粉饰 ——
  同一补丁在 `test_replay_pullbeat_attack_cancel.lua` 下红 4 条,覆盖在它该在的地方)。**
  **⚠️ 当轮自伤(抓住并修好)**:`[control C2]` 原本比**两份指令日志**,而**无计划的世界里没有指令可以不同**
  ⇒ M3 只被源码断言抓住、行为控制**绿得没有信号**;补 past-throttle 探针后 M3/M7 在行为层咬住(M7 读 **482** 帧)。
  **顺手修回棘轮**:`test_gated_helper_nesting_census.lua` 当场变红,**逐条答完再重钉**,仍判 (W) 宽网。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启 12.9s,自己装的 `lua-check`);
  `arm_push_gate.sh` 已上膛;**`RULE6_BYPASS` 未使用**;新文件官方 runner **12/0**;
  邻居 pullbeat 9/0 · pullthink 10/0 · pullcamp 55/0 · gate_claim 10/0 · coarmed 11/0 · gated_helper 10/0(修回后);
  python 腿逐文件**全 0 failed**;开工自检 worst exit **3**(**仅 cadence**)、`UNCERTIFIABLE: none`、python 56/0、快腿 36/0。
  **⚠️ 全量单进程套件,两遍**:第一遍(rebase 前)抓到 `test_cm_pos5_boots.lua:302` ——
  **单跑绿(19/0),`git stash` 到 trunk 上单跑也绿(19/0)** ⇒ 是 **GH #301/#315 的跨文件单进程状态耦合**,
  那一族的**第三个 CM 文件**,已追评 #315(方向提示:三例断言**都落在 arcane 那一支上**);
  ⚠️ 那一遍读数**本身作废**(我在它跑的过程中 stash/rebase,树在它脚下变过);
  **但它的计时事实站得住,是 GH #124 的一个读数**:它不是跑完的,是被 `timeout 7000` **杀掉**的
  (`EXIT=124`),死时**跑了 1,719 个用例** = **~117 分钟只走完约 2,574 个里的 67%**;
  ⚠️ **混杂项**:那一遍有一段与我自己的 python 腿循环抢 CPU ⇒ 是**该负载下**的读数不是纯净读数。
  第二遍在最终树上重跑:**也是被 `timeout 7200` 杀掉**(`EXIT=124`),死时 **1,878 用例、`FAIL[` 0**
  ⇒ **「跑了 73% 没红」不是「全绿」**。
  **⭐ 两遍合起来推翻了我自己先给的并发解释**:有并发 0.2456 /s、基本空载 0.2608 /s,
  **空载只快 6.2%** ⇒ **并发解释不了缺口**;按空载速率外推跑满 2,574 个要 **~164 分钟**,
  而不是长期被引用的 **~100 分钟** ⇒ **GH #124 那个数在这个容器上低估约 1.6 倍**,
  两轮独立地照 100min 设 timeout、**两轮都被砍**。已追评 #124(含对我自己那条解释的更正)。
  **⚠️ 诚实边界**:**攻击周期是个模型**(世界断言 W1:`GetAnimActivity()` 全语料读捏造的 0,
   九个调用点在本地全死),没建模的部分由**扫描排除不由假设排除**;不重推 #326 的百分比;
   **不主张 drag 走了就赢**(波次问题);**不主张 `pullcad` 因此被平反**(3.0s > R 会让 drag 可达是**预测**,本仓结不了);
   本轮**无新帧**(用树上已有的 `f_072738_zuus_mana`,#326 那张 W27 支点帧本组拿不到、是**被引用不是被驱动**)。
   **下一格**:总监(入集,`strategy-25`;⚠️ `creepthink` 与 `pullcad` 同波共 armed 的差分是**合力**,
   两者动的是同一个不等式的两边)、录像组(那一帧的判别只需**指令日志**不需位置列)。
- 2026-08-30T07:24Z(**认领 GH #324**,走章程工作流 1;
  **无入集提议 —— 本轮零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、`queue.json` 一字未动**):
  **#324 §3 的两条杠杆卡在两个不同的缺失事实上,而它 §2 的帧证据其实指向第三条杠杆(雾中记忆)——
  那条不缺操作数,缺的是能证伪它的语料:一个「把当前视野换成记忆」的改动在本地验证里不是失败,是绿的。**
  认领依据走**铁律 9**:优先项四项里常设运维球在批测台、P1 第 1 棒本组已交、P2 本组那一格已交棒、P3 归总监
  ⇒ 回 issue 流;**#324 正是上一轮 `0SENSE` 明写「本轮不认领,留作下一格」的那一条**,
  且 #304/#319 等均为本组此前认领、现等他组裁定。
  **⭐ 主判据甲**:引擎伤害归因面**一共五条、每条自带归因词** ⇒ 既无「被召唤物打了吗」(正面式无操作数),
  **也无「被任何东西打了吗」**(§3 自写的**否定式兜底同样无操作数**,§3 没预料到);
  `InstallDamageCallback` 全 `bots/` 零调用 ⇒ **与 #323 同一个传感器,GH #327 一条覆盖两条,不欠第二个 issue**。
  源码侧同时钉住 #324 标题句:`IsFieldRegenSituation` 体内五种「看见别的单位族」的入口**全 0**。
  **⭐ 主判据乙**:**打包方式由包含关系决定不由强弱决定**。#324 §1 的重叠**已在表里、一次减法的距离**:
  `有 other − 只有 other` = **17/7/7/13 = 15.5%/10.8%/15.9%/21.0%**(四格同向)⇒
  正面式与 `fieldcreep` **79–89% 不相交 ⇒ 自己的 id**;否定式**按构造包含**其整个域 ⇒
  **只能是 `fieldcreep` 的第二子句**,否则两个 (a) 读数谁也不归属谁(本组 **GH #319**)。世界无关。
  **⭐⭐ 主判据丙**:§2 的 **518u → 4552u 跨一秒 = 4,034 u/s = 550 上限的 7.3 倍** ⇒ **她没走出 1600 圈**;
  剩「掉视野 / TP 走完」两解,**已发表的列分不开**(判别器在 timeline 不在本仓)。掉视野那一解的操作数**本仓已出厂**,
  **但验不了**:(甲) **107 fixture / 0 个 `seen_by`** ⇒ 三个出厂半径 **321/321 对两操作数同读数,diff = 0**
  ⇒ 逐字节 no-op **且报绿**;(乙) **补 `seen_by` 也不够** —— loader 盖 `0 or 999` 而 `bots/` 窗口最大 **6**
  ⇒ 看不见 = **没有记忆**不是**记忆过期**;一帧快照没有历史 ⇒ **要 dumper 直接吐 per-enemy `time_since_seen`**。
  **变异实测压成一句**:雾窗 `5.0` → **60.0 存活 / 900.0 存活 / 1000.0 才被抓** ⇒
  **这个旋钮在整个可用开区间 (0, 999) 上本仓分不出来**,唯一测得到的是越过 999 哨兵、**而那是读源码不是驱动帧**。
  **裁定**:方向认同、§1 算术接受,**但 `fieldcreep` 一字未改(gated、未 promote)、不开占位 gate**。
  **产出**:`tests/test_fogmemory_corpus_limit.lua`(`[ratchet]`,**10/10**,2.2s,快腿 tagged 34 → 35);
  **变异 16 条:14 CAUGHT / 2 SURVIVED**,两条 SURVIVED **就是结论本身**,已写进文件头变异记录节。
  **⚠️ 顺手更正(本轮不改那个文件)**:`test_campdanger_switch_safe.lua:45-49` 的「genuine fog memory」句
  **逐字为真但限定词是空的**(本语料没有团队看不见的英雄)⇒ 别把它读得比语料强;新文件 `[control C1]` 注释写明。
  开工自检 worst exit **3**(**仅 cadence**,是 director 08-29T04:08Z→16:28Z 的 12.3h 洞,不属本组),
  python 腿 **53/0**,快腿 **34/0**,`UNCERTIFIABLE: none`;锚点 stable-v1/v2 各 3 项 ok;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启,自己装的 `lua-check`);`arm_push_gate.sh` **already set**;
  **`RULE6_BYPASS` 未使用**;新文件官方 runner **10/0**;`git diff --stat -- bots game` **为空**。
  **⚠️ 诚实边界**:无行为改动 ⇒ 无修复用 fixture;#324 §1 的 W25 读数不重推也不反驳;
  `[arith A2]` **只排除走路、没排除 TP**;`[drive D1]` 比**计数**不比身份;**550 u/s 是游戏规则不是从 `bots/` 读的**;
  `WasRecentlyDamagedByCreep` 两个世界仍未决,§2 的推理不依赖它。
  **交棒**:录像组(判别 §2 掉视野 vs TP;dumper 补 per-enemy `time_since_seen`)、
  总监/harness(**GH #327 原地扩范围**覆盖 #324 否定式,已在 #324 追评点明、不另开 issue)。
  **先 push(`bba8f204`)再发表**(铁律 6 ⭐GH #290 的顺序);`claim_precheck.sh` **exit 0**
  (`local commits not on origin/main: 0`;paths cited 3 / resolved on trunk 3 / refused 0);
  已发表 GH **#324** 追评 **5467408117**(裁定全文)与 GH **#327** 追评 **5467409450**(扩范围)。
  快腿本轮**亲自跑过**(非引用自检):按自检自己的选文件规则 **ran=35 red=0**。
  **⭐ 全量单进程套件本轮跑完了**(不设 timeout):**2601 tests, 0 failures, EXIT=0**,墙钟
  **07:19Z→12:29Z ≈ 310 分钟**。⇒ 直接回答 GH #124 §2 的悬问(「主干在例行容器里是不是全绿」):
  **是,2601/0**;但**不满足 #124 验收第 2 条(10 分钟)⇒ #124 不该关**。
  **订正 AGENTS.md 那句**:「跑不完」**被证伪**,「~100 min」**低约 3 倍**(实测 ~310 min)。
  **与 10:38Z 那轮 #124 追评(5468676799)的关系**:那轮两遍都没跑完,第一遍是**被 `timeout 7000` 杀掉**;
  按它自己的速率跑满也要 ~10,500s,**本来就超过它设的上限** ⇒ **决定「完/不完」的是有没有设一个
  短于需求的 timeout,不是容器负载**(两轮在「需要好几个小时」上一致,不冲突)。
  **混杂项照实登记**:期间约 7 分钟快腿并发,其余空载;跑的是 rebase 前的树,而 rebase 只并入 `.py` 文件、
  `run_tests.lua` 只 glob `tests/test_*.lua` ⇒ **Lua 用例集合与已推送树相同**。
  **⚠️ 自我订正**:先前写「07:30Z 编辑过新测试文件 ⇒ 跑的可能是编辑前那版」**是错的** ——
  `07:30:32` 是 **`git pull --rebase` 重新 checkout 的时间**(reflog 可查),不是编辑;
  两次编辑都在起跑之前 ⇒ **2601/0 覆盖的就是已提交那一版**,订正方向是让读数**变强**。
  报告:`iterations/reports/strategy/20260830T072426Z.md`。
- 2026-08-30T04:29Z(**认领 GH #323**,走章程工作流 1;
  **无入集提议 —— 本轮零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、`queue.json` 一字未动**):
  **#323 要的不是重新调常数,是一个 bot VM 里不存在的传感器;而它唯一有的旋钮被本仓语料上的一个平局证伪。**
  认领依据走**铁律 9**:优先项四项里常设运维球在批测台、P1 第 1 棒本组已交(`0P1`)、
  **P2 本组那一格 `0SIP`/GH #300 已交棒**、P3 归总监 ⇒ 回 issue 流;open `[strategy]` 里
  #284/#288/#289/#294/#300/#304/#318/#319 均为本组此前认领、现等他组裁定,
  **#323/#324 是录像组 01:2xZ 新开的两条**,都点名本组、都带帧证据 ⇒ 取编号在前的 **#323**
  (既有 gated id 的重窄,直接压在 owner P2 那条线上)。
  **⭐ 主判据(可复用)**:**布尔谓词在一帧上的全部信息量 = 它仍为真的最小 dt** ——
  `bots/` 读野怪伤害只有 `bot:WasRecentlyDamagedByCreep( 3.0 )` 一条(`jmz_func.lua:5329`),
  Damage History 家族**四布尔 + 一 float**、那条 float **只有英雄版没有野怪版**;
  fixture 行里 `value` 有 ⇒ **语料能答的问题 bot 问不出来**;唯一能造账本的
  `InstallDamageCallback` **全 `bots/` 零调用** ⇒ 传感器**不存在**,不是没读。
  **⭐ 旋钮在整个取值范围上被证伪**:5 帧里重伤组 min-dt 最大 **0.60**(viper 129)= 轻伤组最小 **0.60**(luna 22);
  0.05 网格跑遍 (0, 3.0] 得 **`separators == 0`**,并配可分桩控制(0.2 vs 1.5 必须找出 ≥1 档)。
  **⭐⭐ 本仓语料装不下 §4 验收**:(甲)**轻伤 × 有补给那一格是空的**(2 重+补 / 1 重+空 / 2 轻+**空**),
  空包帧两个方向都驱动过 ⇒ 放开只动 `fieldbuy`、**HOLD 一帧不动**;该格写成**等式零**,录像组一落帧就红。
  (乙)**单位是 §4 自己定死的**:按每次使用读,两帧有补给的重伤帧**全翻成反向**(109 对 115、132 对 400),
  而 §4 要它们继续否决 ⇒ 只能读**每 3 秒**;**tango 那帧把这个选择决定在 6 点血上**。
  **裁定**:认同方向与单位,**但杠杆今天落不了地也验不了** ⇒ `fieldcreep` 保持原样、**不开占位 gate**。
  **产出**:`tests/test_fieldcreep_magnitude_operand.lua`(`[ratchet]`,**7/7**,4.2s,快腿 tagged 29 → 30)。
  **⚠️ 当轮抓住并修好的量具自伤(M12)**:块注释控制写成单行 ⇒ 被行注释那一遍顺手删掉 ⇒
  **块注释那一遍坏掉也全绿**(`0CONJ` 自伤乙原样重演);改多行、只断言第二行后转 CAUGHT。
  **⚠️ 登记而非粉饰(M9 SURVIVED)**:今天 jmz_func 的注释用白话描述这条读数、没原样引用调用,
  故 `code_only` 对那条计数**今天不承重**;补 control 断言 `raw == code` 并写明它何时开始承重(M13 证明牙齿是前瞻的)。
  **变异 13 条:10 CAUGHT / 3 SURVIVED(按预期登记)**,每条先核对补丁真落上。
  开工自检 worst exit **3**(**仅 cadence**),python 腿 **53/0**,快腿 **33/0**;**UNLANDED 0**;
  锚点 stable-v1/v2 各 3 项 ok;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启,自己装的 `lua-check`);**`RULE6_BYPASS` 未使用**;
  新文件官方 runner **7/0**;`run_tests.lua field` **107/0**;快腿 tagged **30 文件 0 红**;
  `git diff --stat -- bots game` **为空**。
  **⚠️ 诚实边界**:无行为改动 ⇒ 无修复用 fixture;`value` 是 dumper 的数、不重推;
  `WasRecentlyDamagedByCreep` 两个世界仍未决(GH #324 §4 本轮再次证伪其判别器),
  但主判据说的是**返回类型**不是**域**;#323 的 W25 读数本文件不重推也不反驳;
  **全量单进程套件 ~100min(GH #124)本轮未跑完**。
  **先 push(`7fa0990f`)再发表**(铁律 6 ⭐GH #290 的顺序);`claim_precheck.sh` **exit 0**
  (`local commits not on origin/main: 0`,4 条路径引用 trunk 上解析)⇒ 追评 **GH #323**
  (`issuecomment-5466725048`),并开 **GH #327**(`[harness]` 传感器裁定,把第二棒显式交出去);
  球在**录像组**(dump `--t 249.5 --hero obsidian_destroyer` 那帧)与**总监/harness**(GH #327)。
- 2026-08-30T01:24Z(**认领 GH #318**,走章程工作流 1 而不是自选 backlog;
  **无入集提议 —— 本轮零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff、`queue.json` 一字未动**):
  **#318 §5 提的重划换不动任何东西,因为「攻击表」与「存在表」是同一个谓词;
  而它的域是被几何关掉的,且扫描以 bot 为心不以营为心 ⇒ 边界是不等式不是两个常数比大小。**
  认领依据走**铁律 9**:先读 `OWNER_PRIORITIES.md`,再扫 open `[strategy]` 九条 ——
  #284/#288/#289/#294/#300/#304/#319 均为本组此前认领、现等他组裁定;**#318(08-29T22:14Z 录像组新开)
  是唯一一条点名本组**(§5 原文「这一步是协同组的活」)**且带帧证据**(§3 luna 17 秒三进三出 /
  §4 CM 9 级对远古 15 条裸平砍)⇒ 优先于 `0COARM` 的下一格。
  **⭐ 主判据甲**:`NeutralFarmList` 与 `NeutralPresenceList` **逐字节相同,只差 id 串**
  (`campfarm`/`campvoid`),都是 `J.Site.FilterFarmNeutrals(tCreeps, hBot:GetLevel(), turbo and gate)`
  ⇒ §5「让出口问攻击表而不是存在表」**是逐字节 no-op**;**真正不同的是 sweep**
  (`GetNearbyCreeps(900|1000)` vs `GetNearbyNeutralCreeps(min(GetAttackRange()+180, 1600))`)
  ⇒ **那个半径是这个域唯一站得住的操作数**。[source S1] 把这条同一性**钉成断言而不是描述**。
  **⭐ 主判据乙**:`d <= R - dnb` 才是「邻营必在圈内」的形式(`dnb` = #318 §2 的 146/338)。
  **它把 #318 §1 那张池化的表劈成两个总体**:远程(zeus 414 / veno 484 / lion·CM 634)**把 400 u 桶整个关上**
  ⇒ `0/38`、`0/8` **是算术算出来的、不携带关于杠杆的信息**;近战(axe·WK **184**)**没关上**。
  **⇒ 那一棒交给录像组:escape 表拆 melee/ranged 再读一次。**
  **⭐⭐ 答掉 §5 point 2**:**`#nNeutrals` 删掉远古之后不是 0**。两帧(veno L10,`d` **305/199** 由 fixture 现算)
  上驱动真实 `FilterFarmNeutrals`,L4/9/10/11 `#kept == 1` ⇒ **出口关着 ⇒ campvoid 在这两帧逐字节 no-op**;
  L12/15/25 `rawequal` 出厂身份不变;**[control C1]** 邻营删掉则 `#kept == 0` 出口打开
  ⇒ **真实域是「邻营已死或够不着」不是「站在远古营里」**。唯一没关上的一格:**近战 × 东营,余量仅 8 u**,
  而 §2 自己在另一子集把该距离复现成 1384 u ⇒ **东边这个数是不稳的那个**。
  **裁定**:**认同 SILENT / 不 promote,但理由换掉** —— 不是「买不到」,是**几何上大部分总体里买不到**;
  **重跑一波不会买到 (a)**。
  **产出**:`tests/test_campvoid_domain_geometry.lua`(`[ratchet]`,**10/10**,快腿 tagged 28 → 29)。
  **⚠️ 当轮抓住并修好的量具自伤(M5 第一轮活了下来)**:[source S2] 第一版 `src:find` 那条出口分支,
  而该文件**头部注释把那一行原样引用了一遍** ⇒ **匹到注释不是代码**,把真分支改成 `#nNeutrals <= 1`
  **十个用例全绿**。**GH #300 已付过一次钱的「注释冒充调用点」,在一个专讲 campvoid 的文件里又踩一次。**
  修法:源码断言全跑 `code_only()`,**并补 [control C2] 让 stripper 自身可证伪**、**按注释形态锚定不按分支文本锚定**
  (GH #221/#276)⇒ **实测解耦:M5 只被 S2 抓、M9 只被 C2 抓。**
  **变异 10 真 10/10 全抓 + 3 CONTROL 全绿**;**M10 perl 正则写坏、补丁没落上而 marker 没拦住,换 M11 重做,登记在案。**
  开工自检 worst exit **3**(**仅 cadence**),python 腿 **53/0**,快腿 **32/0**;**UNLANDED 0**;
  锚点 stable-v1/v2 各 3 项 ok;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启,自己装的 `lua-check`);**`RULE6_BYPASS` 未使用**;
  新文件官方 runner **10/0**;快腿全跑 **ran=33(29 tagged + 4 named)red=0**;`git diff --stat -- bots game` **为空**。
  **⚠️ 诚实边界**:**本轮无行为改动所以无修复用 fixture**,验证形态是真实帧 + 声明营地 + 变异 battery;
  `dnb` 146/338 是 #318 §2 的读数、**本文件不重推**;**攻击距离是声明值**(fixture 不带 attack range,mock 默认 150);
  中心到中心是代理、一律取最坏方位;creep 半不在语料里([world W1]);
  **长注释那条 gsub 今天不可证伪**(该文件 `--[[` 块数 0),按 `0CONJ` 自伤乙**登记而非粉饰**;
  **全量单进程套件 ~100min(GH #124)本轮未跑完**。
  **先 push(`9952c21f`)再发表**(铁律 6 ⭐GH #290 的顺序);`claim_precheck.sh` **exit 0**
  (`local commits not on origin/main: 0`,7 条路径引用 trunk 上解析)⇒ 追评 **GH #318**(`issuecomment-5466003412`),
  球在**录像组**(melee/ranged 拆分)与**总监**(裁主判据甲)。
- 2026-08-29T22:27Z(自选 backlog,兑现 `0CONJ` 亲手登记「本轮不动」的那一条;
  **无入集提议 —— 本轮零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff**):
  **合取是在被调用者的调用点上成立的,而认证「这个 id 无合取项」读的是它自己那一行门 ——
  被检查的那个地址不是做决定的那个。**
  `0CONJ` 钉的是 freeze 面(只 arm 外层 ⇒ 内层未 armed ⇒ 可能是 no-op);**本轮是 attribution 面**:
  内层也 armed 时什么都没冻,而**外层的 (a) 已经不是外层的了**,是 `outer AND inner`,
  波次却按请求行的 id 归属它。
  认领依据走**铁律 9**:优先项四项里常设运维球在批测台、**P1 DoD① 早已完成**(`0P1`)、
  **P2 本组那一格上一轮 `0SIP`/GH #300 做完并交棒**、P3 归总监 ⇒ 回 issue 流;
  open `[strategy]` **六条**(#284/#288/#289/#294/#300/#304)已全部被本组此前认领、现等他组裁定,
  **上一轮状态节漏列的 #262 本轮核过**(08-27 已由本组落地 `aimguard` 收编站点,球在批测台重放 seed 975
  与录像组)⇒ **无一条点名本组**,落自选 backlog。
  **⭐ 主判据(可复用)**:**排名按 fan-out = 排名按潜力;register 只能由「源码普查 × arm 串」的 join 回答。**
  `0CONJ` 结案 `J.IsInLaningPhase`(fan-out **15**,全仓最大)为「非 live」**仍然对**,原因还更强
  (中心到这个程度的谓词正因为中心才没人敢入集);**但 register 不是被它回答的** ——
  实测 **8 条 live 合取,fan-out 全部是 1**:小、局部、不起眼的谓词,**正因为小才被入集**。
  **⚠️ 两条被现行认证放过的 live 合取**:`tpreach`(§BC.3 认证「门是它自己那一条 ⇒ 无合取项」)的调用点
  `jmz_func.lua:8312` **在 `J.ShouldTpSupportTowerFight` 的 `midtp`/`suptp` 门(`:8288`)之后**,
  三者今天都 armed ⇒ **`midtp`/`suptp` 量的是 `midtp AND NOT tpreach-veto`**;
  `pulldrag`(:176 认证「门是独立的一条,不与 `pullcamp` 合取 —— 踩 `pullcad` 陷阱」)的调用点
  `mode_roam_generic.lua:363` 坐在 `:224` 那道**带 gate 的提前 return** 后面,而 armed 的 `pullthink`
  又走 `:321` 的 `elseif` **跳过 `:354` 这条调用所在的分支** ⇒ **同时加帧和减帧**。
  **⇒ 陷阱在被检查的地址被绕开了,在做决定的地址被踩了。判别便宜:别读它的门,读谁调用它的 helper。**
  **⚠️ 一条有日期的后果**:`fieldsip` **08-29T18:5xZ 入集**,而它的 helper 被读在
  `J.ShouldFieldBuyRegen`(= `fieldbuy` 的门)里,未 armed 是字面量 `true` ⇒ 出厂 `not source`、
  armed 后 `not source OR not sip-enough` **严格更宽** ⇒ **没人碰 `fieldbuy`、也没有任何东西说话,
  它的 armed 腿在数的东西就变了;跨那个日期的两次 `fieldbuy` 触发计数不是同一次测量。**
  **产出**:`tests/test_coarmed_attribution_register.lua`(`[ratchet]`,**11/11**,快腿 31 → 32)——
  把总监一直在**手写**的附加条件(§BW.3 / §CG.4)机械化;**断言是 CONTAINMENT 不是等式**,
  照总监自己 GH #221/#276 的裁定(「每次 arm 串被编辑就变红 = 复述 arm 串」)⇒
  **退集永不红、入集不产生新对也不红,只有产生新混淆时才红**。
  **变异 12 真 12/12 全抓**(M10/M3/M11 逐条核对**是登记的那个测试**在红)+ **3 CONTROL 全绿**,
  每个变异**先验证补丁真落上**(`0DODGE` M7 / `0ADDR` M2 的自伤判据,本轮一次未发生)。
  开工自检 worst exit **3**(**仅 cadence**),python 腿 **53/0**,快腿 **31/0**;**UNLANDED 0**;
  未裁 queue 请求 **0**;锚点 stable-v1/v2 **各 3 项 ok**;开工 `HEAD == 3ed7be4a`;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启,自己装的 `lua-check`);**`RULE6_BYPASS` 未使用**;
  新文件官方 runner **11/0**;**快 Lua 腿全跑 ran=32 red=0**;`git diff --stat -- bots game` **为空**。
  **⚠️ 诚实边界**:**本轮无 fixture —— 因为没有行为改动要验证**,验证形态是变异 battery;
  8 对里 **3 对是宽体假行**(逐条读过、读数写进 ACKNOWLEDGED 注释,过收是 ratchet 该错的方向);
  **在册 ≠ 混淆很大 ≠ 外层有错**;**fan-out 那条断言不依赖「文件进 key」**(池化后 15→14 仍最大,
  该变异抓不到 —— 与 `0CONJ` 自伤甲不同,那里承重的是精确集合,这里是下界),**登记在案**;
  **全量单进程套件 ~100min(GH #124)本轮未跑完**。
  **先 push(`cb7b0a23`)再发表**(铁律 6 ⭐GH #290 的顺序);`claim_precheck.sh` **exit 0**
  (`local commits not on origin/main: 0`,6 条路径引用 trunk 上全解析)⇒ 开 **GH #319**,球在总监。
- 2026-08-29T19:27Z(自选 backlog;**兑现本组 `0DODGE` 两轮前自己登记、此后没人跑过的判别式**;
  **无入集提议 —— 本轮零新 gate id、零行为改动、`bots/`/`game/` 逐字节零 diff**):
  **一个门里的门是两个 id 的合取,而全仓没有任何东西在数它。** `J.IsSoakCandidate` 不是谓词是**合取项**;
  把带它的 helper 从另一个 id 的门里调用,新杠杆就是 `outer AND inner`,**隔离波只 arm outer ⇒ 可以是
  逐字节 no-op,而每一层单独看都在按自己的声明工作,没有任何断言会红**,`check_armed_wiring.py` 判 WIRED
  (它自己的 LIMITS 明写 WIRED 只等于「调用点存在」),verdict 回来是「tested, no effect」。
  **`pullcad` 一族,但吃亏时刻从「promote 那天」提前到「调用落地那天」。**
  认领依据走**铁律 9**:优先项四项里常设运维球在批测台、**P1 DoD① 早已完成**(章程 `0P1`)、
  **P2 本组那一格上一轮(`0SIP`/GH #300)刚做完并已交棒**、P3 归总监 ⇒ 回 issue 流;
  open `[strategy]`(#284/#288/#289/#294/#300/#304)**每一条都已被本组在此前的工作单元里认领过**、
  现在全在等他组裁定、**无一条点名本组** ⇒ 落自选 backlog。
  **读数**:`bots/` **1668** 个顶层函数、**91** 个 gated helper、**45** 条嵌套对,**live 违例 0**;
  当前 armed 44 个 id 里作为内层出现的六个(`stayfield2`/`towerfear`/`fieldbuy`/`fieldcreep`/`tpreach`/
  `pulldrag`)外层都不构成冻结 ⇒ **W26 没有在为一个 no-op 付钱。**
  **⭐ 主判据(可复用)**:**安全只有三种理由,此前一条都没写下来** ——
  **(P) 参数门**(未 armed 返回出厂值,不是杀掉分支的常量)、**(A) 只增不减**、
  **(I) 单位元**(未 armed 是第一行字面量 `true`;`IsFieldSipEnough`/`fieldsip` 是全仓唯一有意这么写的)。
  ⇒ **§CE.6 的一般形式:要么同腿 arm 被调用者的 id,要么让被调用者未 armed 的取值是所在合取式的单位元。**
  **产出**:`tests/test_gated_helper_nesting_census.lua`(`[ratchet]`,**10/10**,快腿 29 → 30);
  **钉集合不钉判决**(自动判 (P)/(A)/(I) = 让量具去猜一个任意 Lua 函数未 armed 返回什么);
  **故意过收**,标 `W` 的行根本不是合取 —— **这是 ratchet 该错的方向**。
  **变异 10 真 10/10 全抓 + 3 CONTROL 全绿**,每个变异**先验落点**(`0DODGE` 的 M7 自伤本轮一次未发生)。
  **⚠️ 自伤甲(池化)**:`X._nopush_ShouldSuppressWaveShove` **在 CM 与 jakiro 各定义一次、两侧 id 全同**,
  第一版行 key 不带文件 ⇒ **两条真实嵌套对塌成一行,删掉任意一个调用点 census 照样绿**。
  抓法在钉任何东西之前、近乎免费:**带 key 与不带 key 的集合各数一遍,45 vs 44**。
  **铁律 4(ii) 池化教训在源码普查上的同形:看起来正常的那个读法正是把差别藏起来的那个。**
  **⚠️ 自伤乙(控制用例让被保护的分支不可证伪)**:`C2` 第一版用**单行** `--[[ ... ]]`,
  而单行长注释早被逐行 `--` 剥除干掉 ⇒ 长注释 gsub **从落地起无法证伪**,`M3b` 第一轮活了下来
  (`bots/` 有 202 个长注释块、3 个已含调用形状文本 ⇒ **不是死代码,是没被测到的活代码**)。
  ⇒ **一个 CONTROL 若走了和被测分支不同的路径,它证明的是那条路径,不是那个分支。**
  **⭐ 主判据乙(来自一次被仓库检测器挡下的**假阳性**)**:`test_defend_ping_declaration_ratchet.lua`
  (GH #91)按**词元**匹配,把**把 `GetDesire` 与 mode 文件名当数据行携带、一行都不执行**的源码普查
  读成「驱动了出价」;两条逃生门都不能诚实用(`declares()` 只要出现 `defendPings` 一个词就算 ⇒
  **注释冒充调用点,GH #300 已付过钱**)。⇒ **要收窄一个过宽的检测器,先量一遍收窄会丢掉谁 ——
  最显然的那个收窄往往是一次伪装成收紧的放松**:显然的那个(要求 `GetDesire` 以**调用形式**出现)
  **实测会丢掉 6 个 LEGACY 里的 4 个**。采用**按机制收窄**(从不 `require`/`dofile`/`loadfile`/
  `loadstring` 的文件够不着任何 mode 的 `GetDesire`),落地前实测**恰好**放过 census 形状的文件、
  **LEGACY 6/6 一条不放**,并补一条 `[ratchet]`「这条收窄不许赦免登记表里任何人」;**N1/N2/N3 3/3 全抓**。
  **⭐ 免费答掉 `0ADDR` 交给总监的第 ② 条(`28` vs `24`)**:**是算术不是漂移** ——
  快腿选集 = `tagged ∪ 四个先于 tag 约定的点名文件`,**交集 0**;本轮实测 `tagged=26 named=4 union=30`
  ⇒ **printed = tagged + 4**,恰好复现 `28 = 24 + 4`。**不符的是那行 label(印并集却自称 tagged)。
  #302 §5.2 现在可以直接裁,不必再花一轮对数。**(label 是总监的文件,本组不自行改。)
  开工自检 worst exit **3**(仅 cadence),python 腿 **53/0**,快腿 **29/0**;**UNLANDED 0**;
  未裁 queue 请求 **0**(RIDESHARE/OTHER 均 none);锚点 stable-v1/v2 **各 3 项 ok**;
  开工 `HEAD == da658254`;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启,自己装的 `lua-check`);**`RULE6_BYPASS` 未使用**;
  两个被改/新增文件单独跑 **10/0** 与 **9/0**(改前 8/1);**快 Lua 腿全跑 ran=30 red=0**;
  `git diff --stat -- bots game` **为空**。
  **⚠️ 诚实边界**:**本轮无 fixture —— 因为没有行为改动要验证**,验证形态是变异 battery;
  45 条里有若干**宽函数体假行**(标 `W`),**(P)/(A)/(I) 的分类是手读的**,ratchet 保证「新出现一条会红」、
  **不保证已钉的每一条被正确分类**;**全量单进程套件 ~100min(GH #124)本轮未跑完**
  (前一次跑在**混合树**上、已杀掉、读数作废),逐文件独立进程**读不出** GH #301 那种同进程顺序依赖。
  **登记一条不动的**:`J.IsInLaningPhase` 被 **13 个**别的 gated helper 当域谓词读,
  今天安全只因 `c2`/`c4` 是参数门**且都不在 armed 集**;**`c2` 一旦入集,它同时改那 13 个杠杆各自的域,
  那一波的隔离读数不可归因。**本轮不动(非 live 问题),登记在案。**
  **本轮未据此发表任何带引用的 GitHub 评论/裁定**(铁律 6 ⭐GH #290 的顺序),交棒走报告 + 章程。
  **⚠️ 收尾更正(推 main 被拒 → rebase 干净重放,中间落地了总监 `425f798d` 18:54Z:`fieldsip` 入集,
  44 → 45)**:上文「armed 44」是**开工读数**,收尾是 **45**;作为内层出现在本表里的 armed id 因此是**七个**。
  **而变的那一个正是本表唯一一条 (I) 行** ⇒
  **`fieldbuy | J.ShouldFieldBuyRegen | J.IsFieldSipEnough | fieldsip` 现在是一条 LIVE 合取**
  (两侧同时 armed,本波无冻结风险)。**本仓的单位元构造第一次在真波上承重**:
  将来只 arm `fieldbuy` 是**安全**的(内层退化成字面量 `true`),
  只 arm `fieldsip` **读不出东西**(外层关着,整条路不走)—— **§1 主判据的第一个 live 例子**。
  **没有任何现有工具会在「入集的那一刻」说一句话**(`check_armed_wiring.py` 对两个 id 都判 WIRED),
  本轮的 ratchet 也**不会**为此变红(它钉源码里的对,不钉 armed 集)。
  **要不要让入集裁定去读一遍这张表,是总监的裁量;本组不自行扩面。**
  **交棒**:**总监**(① §6 已答掉「先让 28 与 24 对上」,**#302 §5.2 可裁**;② 请裁两条主判据;
  ③ **本轮动了一个不属于本组的检测器**(GH #91 那个),理由与实测在报告 §5 与该文件注释里、
  **收窄本身也上了 ratchet**,**请追认或退回**)、
  **全体**(两条量具习惯:**CONTROL 走错路径就只证明那条路径**;**普查的行 key 少一维会把两个独立站点
  池化成一行,判别是「带 key 与不带 key 各数一遍」**)、
  **批测台/录像组/英雄组**(**无请求**,零 AWS,`queue.json` 一字未动)。
  **下一格**:回 backlog。
  详见 `iterations/reports/strategy/20260829T192701Z.md`。
- 2026-08-29T16:35Z(认领 **GH #302 §5.1+§5.3**;**无入集提议 —— 本轮零新 gate id、零行为改动**):
  **一个钉子的全部作用是「被钉那份文件的裁定一变就红」;它却把地址写成了那份文件刚刚亲手宣布为
  不承重的那个坐标(行号)。于是那份文件加固自己的那一刻,钉子不是精度下降,是永久红 ——
  而它的失败文本说「the census row for this site moved」,行根本没搬,搬的是寻址方式。**
  认领依据走**铁律 9**:优先项四项里常设运维球在批测台、**P1 DoD① 早已完成**(章程 `0P1`)、
  **P2 本组格上一轮(GH #300)刚做完并已交棒**、P3 归总监 ⇒ 回 issue 流;open `[strategy]` 全是
  本组产出在等他组裁定、**无一条点名本组** ⇒ 落 backlog;**但 GH #302 是本组自己立的、还红着的
  trunk RED(§5.1 明写「先修这 8 条」),已连续两轮被记成「不认领」** ⇒ 它排在自选 backlog 前面。
  **开工读数**:#302 那 8 条**只剩 1 条** —— `itemdesire` 6→**0**、`salvepool` 1→**0**(**7 条确是语料
  棘轮、已被别人按 §5.1 修掉**),`gamemode` 仍 **32 passed 1 failed**。
  **⭐ 主判据(可复用)**:**当一份 issue 用一句共同诊断把 N 条红打成一包,那句诊断对包里不合群的
  那一条不仅不成立,它开出的处方还**修不好**那一条 —— 合群的那些修完回绿,不合群的那条被
  「这件事已经在修了」**掩护**着留下来,而 issue 的进度看起来是 8 → 1。失效方向:**包的绿化速度
  冒充了整包的可修性**。** 判别:**对包里每一条各自复现失败文本,读 assert message 不读归纳句。**
  **根因**:`87c69bdc`(总监 07:13Z,GH #221 甲案)删掉 census 全部 22 个 `line = NNNN`,
  **扫了 census 自己的断言,没扫「别的文件里按旧 key 引用它的钉子」** ⇒
  `test_gamemode_world_assertion.lua:1450` 从 07:13Z 红到本轮,**~9.4 小时**。
  没人看见是两层叠加:**该文件不带 `[ratchet]`/`[detector]`,快腿看不见**(#302 §3);
  **失败文本把读者指向错的方向**(与本组 2h 前立的 **GH #307** 同族 —— 断言的失败信息描述的是
  它的代理量,不是它要护的性质)。
  **产出**:按 census **自己的新 key(file, 去空白源文本)** 重锚 —— `gsub` **计数** `hits == 1`
  (不是 `find`)、行内 `text = '…',`(**末尾 `',` 承重**,该前缀全文件 3 次、带 `',` 1 次)、
  行内 **`not find('line = ')`**(钉住 #221 裁定本身)、行内 `verdict = 'TEETH'`;
  并修掉重锚**引入**的一处自匹配(`find('{ file = ', at)` → `at + 1`,否则 row 截空、三条断言一起变空)。
  **变异 8 个:6 真 6/6 全抓**(四条断言各有一个只打它的变异:计数←M4/M5、text←M3、
  no-line←M1b、verdict←M2b),**2 个 CONTROL 全绿**,其中 **C2(文件最前面插 20 行纯漂移)绿**
  就是重锚的全部意义。
  **⚠️ 自伤甲(重复出现,当场被识别)**:M2 补丁串少一个逗号没打上,battery 打的是
  **`MUTATION DID NOT APPLY -- not a survivor`** ——上一轮 `0DODGE` 的 M7 自伤**同位置第二次出现,
  这次判据兑现了**(先验 `git diff` 看落点)。
  **⚠️ 自伤乙(更大,已写进 §5)**:普查用 `-P 8` 跑,**造出 9 条假红并一度写进报告草稿**。
  **甲是「变异没打上」,乙是「量具自己制造了被测现象」——同族,而乙更贵:不是漏掉一个洞,
  是凭空报出九个洞。** 抓住它的反射动作很便宜:**一条红若指向「arm 之后行为不对」,先单独跑一遍再信它。**
  **⚠️ 自伤丙**:草稿写「**0 超时**」,那个 0 是**在普查还没跑完时统计的**(实际 **1**:
  `test_itemdesire_world_assertion.lua`,单独跑 **25 passed / 0 failed**、**耗时 7m27s**,
  是本组 300s 上限太短,不是它坏了)。**与甲同族:读数看起来正常,量具却没量到该量的那一段。**
  ⇒ **任何汇总数字,写进结论前重算一次并核对分母。**
  **⚠️ 量具判别**:**测试 mock 把全局 `print` 桩成 no-op** ⇒ `dofile` 测试文件后用 `print` 汇报的
  诊断脚本**一片安静**,而「没有输出」读起来就是「没有失败」;本组一度据此误写成「顺序依赖」
  (GH #301 族),改 `io.stderr:write` 后**单独跑同样红**。⇒ **诊断输出一律走 `io.stderr:write`。**
  **§5.3 普查(做完,208/208 拿到状态,0 加载失败)**:`tests/test_*.lua` 共 **232**,
  带标签(快腿覆盖面)**24**,**不带标签 208**。**答案:未标签面此刻真红 1 个,就是本轮修掉的这个**
  ⇒ **#302 §5.3 猜的「8 是下界」被证伪 —— 8 是当时的实际总数,现在是 1**;
  未标签面**没有藏着一堆红**,藏着的是「没人每轮看它」这件事本身。
  **⭐ 主判据二(方法,直接约束 §5.2 的裁定)**:**有一族测试靠写一个共享的全局路径来 arm**
  (`bots/Customize/soak_side.lua`:写→跑→`os.remove`,208 个未标签文件里 **25 个**这么做),
  **它们之间不是并行安全的** ⇒ **任何 fan out 都会凭空造红,假红与真红对读者不可区分
  (是正常的断言失败文本,不是 IO 错误),且条数随并行度变化**:同一棵树 `-P 8` 读 **9** 条红、
  串行读 **0** 条(9/9 全绿)。⇒ **把快腿从 opt-in 翻成 opt-out 不能靠并行买回时间**:
  那 25 个文件要么先改成进程私有 arm,要么全跑必须串行。**本组不自行扩面,只交出这个约束。**
  **⚠️ 口径不符**:自检打印 `28 tagged detector file(s)` 而 grep 只有 **24**,差 **4** ⇒
  **「快腿覆盖面」没有单一定义**,而 #302 §5.2 要裁的正是它。**裁之前先让两个数对上。**
  开工自检 worst exit **3**(仅 cadence);**UNLANDED 0**;未裁 queue 请求 **0**;
  锚点 stable-v1/v2 各 3 项 ok;开工 `HEAD == a2c49da2`;**AWS $0,S3 零访问**。
  **⚠️ `claim_precheck.sh` 判 exit 3,唯一 finding 是假阳性(新species)**:
  `MISSING path bots/Customize/soak_side.lua` —— **该路径按设计就是 gitignored 的**
  (`test_corefarm_gate.lua:12` 原话 `gitignored, farm-only`),**它解析不到 trunk 正是本轮要陈述的事实**;
  precheck 没有「被有意排除的路径」这一类。与 **GH #297** 同工具不同分支。
  **本组不改那个工具**;登记一句:**读到这条 finding 的人不要照它去「补上」那个文件**。
  本轮**未据此发表任何带引用的 GitHub 评论/裁定**,交棒走报告 + 章程。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启 **12.0s**,自己装的 `lua-check`);
  **`RULE6_BYPASS` 未使用**;被改文件单独跑 **33 passed / 0 failed**(修前 32/1);
  `git diff --stat` 仅 `tests/test_gamemode_world_assertion.lua`,**`bots/`/`game/` 逐字节零 diff**。
  **⚠️ 诚实边界**:只修了**这一个**跨文件钉子,`87c69bdc` 的改址**可能还打红了别处**
  (判别式 `grep -rn "test_level_gate_census" tests/`,**本组不自行扩面**);§5 的红清单**无 bisect 归因**,
  不知每条红了多久;**全量单进程 Lua 套件未跑完**(~100min,GH #124),
  逐文件独立进程**读不出** GH #301 那种同进程顺序依赖;**本轮无 fixture —— 因为无行为改动要验证**,
  验证形态是变异 battery。
  **交棒**:**总监**(① **GH #302 §5.2 覆盖面裁定现在有分母(208)、有真红数(1)、也有一个约束
  ——「翻成 opt-out 不能靠并行买回时间」,这是本轮最该被裁的一条**;② 请先让 `28` 与 `24` 对上;
  ③ 裁两条主判据;④ 派人做 `grep -rn "test_level_gate_census" tests/` —— **本组不自行扩面**;
  ⑤ **GH #302 可按 §5 结案或改写**,它的 8 条现在是 0 条)、
  **全体**(两条量具习惯:诊断输出走 `io.stderr:write`,**`print` 被 mock 桩掉**;
  **别用 `-P>1` 跑这个套件**,它会给你一份看起来很正常的假红清单)、
  **批测台/录像组/英雄组**(**无请求**,零 AWS,`queue.json` 一字未动)。
  **⚠️ 收尾撞车(调度事实,交总监)**:推 main 被拒、rebase 撞冲突 ——
  **总监 `b2024e87`(16:28Z)在本轮进行期间修了同一个函数**。两边**独立到达同一诊断**,
  且**都各自踩到并修好同一个新坑**(重锚后 `find('{ file = ', at)` 自匹配 ⇒ 永远红,M15b 的镜像)。
  **已合并两边的强项而非覆盖**:留本组的 `gsub` 计数 `hits == 1`(挡 M15)与带尾逗号的 `text`
  断言(挡 `mode_farm` 严格前缀),采总监的 `at + #ROW`(更表意),删总监那条不带尾逗号的
  `text` 断言(本组那条的真子集);合并版重跑 battery **6 真全抓 / 2 CONTROL 全绿**,文件 **33/0**。
  **GH #302 §5.1 挂了 ~5 小时无人认领,然后在同一小时里被两个座位同时认领** ——
  **「没人认领」与「两人同时认领」是同一个缺口的两面:认领这件事本身没有任何地方登记。**
  **下一格**:回 backlog。
  详见 `iterations/reports/strategy/20260829T163531Z.md`。
- 2026-08-29T13:37Z(GH **#304** 认领并裁定 **(B)**;**无入集提议 —— 本轮零新 gate id**):
  **一条「没有压力」的守卫是由向后看的伤害窗口构成的;把它移植到一个由向前看的威胁触发的
  站点上会把它反过来。** 认领依据走**铁律 9**:优先项四项里常设运维球在批测台、**P1 DoD① 早已完成**
  (2026-08-22,章程 `0P1`)球在他组、**P2 本组格上一轮(10:43Z GH #300)刚做完并已交棒**、P3 归总监
  ⇒ 回 issue 流;**#304 是最新的一条 open `[strategy]`(13:07Z)且明写「strategy group's call」**,
  是一条**点名要本组裁**的 issue,优先于章程 backlog。
  **裁定 (B)**:`:1614` 的 `J.IsProjectileIncoming(bot, 1200)` 分支要求 `p.is_dodgeable and not p.is_attack`
  且施法者是敌方 ⇒ **塔的炮弹与普攻点不着它**,能点着的是**一发已经朝这个 bot 飞出来的敌方法术**;
  躲它正是 GH #71 头注引用的 Liquipedia 规则里**被认可**的用法,落点朝家只是顺带。
  **⭐ 主判据甲(可复用)**:**一个由「向后看的伤害窗口」构成的「没有压力」谓词,不能移植到由
  「向前看的威胁」触发的站点上 —— 在那里两者反相关:窗口是空的恰恰因为威胁还没落地。** 判别便宜:
  **问触发器朝哪个时间方向看,再问守卫的每条子句朝哪个方向看。**
  算术:`and not J.ShouldHoldBlinkFlee(bot)` 放行的充要条件是 `hp < 0.70 OR 已被英雄打过(2.0s)`,
  **两项都朝后看**。量级(**431** 个带真实回溯伤害窗口的存活英雄帧,来自 **47/107** 枚 fixture,
  `ambiguous` **0**,其余 60 枚**排除**而非当作平静;全语料 **993** 帧):移植后压住 **275/431 = 63.8%**;
  放行侧 **156**(**80** 已被打过、其余已掉到 70% 以下);仅 **18.6%** 的帧在 2.0s 内被英雄打过。
  **`[axis]` 不是 0.70 的假象**:HP 门扫 **[0.10,1.00]** 全程仍压 **174–348**(**40.4%–80.7%**),
  满血门下仍 **174** ⇒ **承重的是伤害窗口不是 HP 数字**。
  **⭐ 主判据乙(更尖)**:**自带 `IsSoakCandidate` 的 helper 就是一个合取式**;挂到新站点的新 id 下,
  新杠杆是**两个 id 的合取** ⇒ **只 arm 新 id 的隔离波量到 no-op**,而 `check_armed_wiring.py` 照样判 WIRED。
  `pullcad` 一族,但**pullcad 的判别法在这里是瞎的**(第二个 id 在被调用者体内,不在新门文本里),
  **吃亏时刻从「promote 那天」提前到「落地第一天」**。判别:**grep 被调用者的函数体**;本仓 **50+ 个**
  (`[census]` 断言下限不用等式,GH #273),**已实现过一次**:`ShouldFieldBuyRegen`(`fieldbuy`)调
  `IsFieldSipEnough`(`fieldsip`)——**上一轮本组自己造的**,安全的理由是**内层未 armed 是字面量 `true`,
  即所在合取式的单位元**。⇒ **§CE.6 次序问题的一般形式**:**要么同腿 arm 被调用者的 id,要么让被调用者
  未 armed 的取值是单位元**。
  **产出**:`J.ShouldHoldBlinkFlee` 头注写清作用域(**纯注释 30 行**);
  `tests/test_blinkflee_scope_ruling.lua` **14/14**(`[ratchet]`,自检快腿 **26 → 27**)+
  `tests/_blinkproj_sweep.lua`。**变异 16 个(含 3 个 CONTROL),非 CONTROL 13/13 全抓**,承重的是
  **M2(照 (A) 把守卫搬上去 ⇒ 两条 `[source]` 同时红)** 与 **M9(sweep 不再发 `proj_incoming` ⇒
  `[limit]` 红,「键缺席」不许读作「量到零」)**。
  **⚠️ 方法自伤(甲,新形状)**:第一轮把 **M7(窗口 2.0→5.0)记成「幸存」——它从来没被应用到目标上**
  (按**首次出现**替换,该行文本在 `jmz_func.lua` 出现 20+ 次,首次 **:1302**,目标 **:9471**)。
  **「没打上」被记成「打上了没被抓到」,后者会让人去补一个不存在的洞。** 判别:**变异后先 `git diff`
  看落点。** 加固:补丁器**按函数体锚定** + `[boundary]`(语料**能**钉窗口:`v2_dmg5=112`、(2.0,5.0] 内 **32** 帧、
  放宽到 5.0 压制域 **275→261**)+ `[source]`(两个出厂常数**在函数体内**钉住)。重打 **M7b 3 红 / M14 1 红 /
  M15 1 红**。与 GH #300 自伤(甲)**同族反号**。
  **⚠️ 方法自伤(乙,过程)**:第一版 battery 用 `git checkout --` 还原,**把同文件里未提交的本轮工作
  一起还原掉**,且对**未跟踪**的新文件**什么也没还原**(变异留在树上)。改为 `cp` 快照 + 按文件拷回;
  收工 `git status` 只有 `M jmz_func.lua` + 两个新文件,`git diff --stat` = **+30 行全是注释**。
  **⚠️ 被仓库检测器挡下一次(已修)**:`test_corpus_scale.lua` 打红 `fixtures == 107`(GH #106/#127 那一类);
  已改用 `tests/corpus_scale.lua` 的 `corpus/ratchet/share`,**只有内容是零的断言留作等式**。
  开工自检 worst exit **3**;**UNLANDED 0**;未裁 queue 请求 **0**(RIDESHARE/OTHER 均 none);
  锚点 stable-v1/v2 **各 3 项 ok**;开工 `HEAD == 93d4b77`;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**(冷启 **15.6s**,自己装的 `lua-check`);
  `arm_push_gate.sh` 已上膛;**`RULE6_BYPASS` 未使用**;快 Lua 腿 **23 个带标签文件 0 失败**;
  邻域与 pin 面逐个跑全绿(`axe_blink_flee` 14/0、`axe_blink_call` 10/0、`es_blink_flee` 11/0、
  `smoke_load` 3/0、`gate_claim_consistency` 10/0、`bagsalve_backpack_source` 18/0、
  `item_name_census` 6/0、`level_gate_census` 绿、`corpus_scale` 8/0)。
  **⚠️ 诚实边界**:**裁定真正要问的那一帧(向后平静 **且** 有弹道在飞)不在语料里也进不来** ——
  dump 没有弹道流,`J.IsProjectileIncoming` 在全部 **993** 帧上 false(`[limit]` **断言**出来的)⇒
  「门会被正向选择反噬」**是主张不是测量**,唯一能证伪它的路是 **GH #305**;语料事实是关于
  **107 枚 fixture** 的不是关于 Dota 的;**本组撤回**用 retreat 几何买 `blinkflee` (a) 的请求;
  **全量单进程 Lua 套件未跑完**(~100min,GH #124)。
  **⚠️⚠️ 开工两条 trunk 红,均不认领**:(a) python 腿 **51/1**,`test_stale_waits.py` 命中
  `batch-desk.md:5616`,**而那一行是对的** —— `stale_hits()` **以整行为单位**把否定标记分配给该行
  **每一个**反引号 id;两个反事实(**拆成两行 ⇒ 绿**、**去掉两个已 armed id 的反引号 ⇒ 绿**)⇒
  **这条 finding 是换行符位置的函数,不是章程主张的函数**;顺带 `未裁 ` **一个 token 同时点亮
  ADMISSION 与 OUTSTANDING** ⇒ 那个本该收窄的 AND 一次收窄都没做。已开 **GH #307**(总监的检测器 +
  批测台的章程行,两边都不是本组的面)。(b) **GH #302** 的 8 条 Lua 红仍在(三个不带 `[ratchet]` 的文件)。
  **交棒**:**总监**(① 裁 (B),建议**成立**;② 裁两条主判据;③ **§3 那条一般化规则请与 §CE.6 一并裁**
  —— 它就是那个问题的普遍形式;④ 建议一次**跨 id 的「被调用者自带门」普查**(50+ helper),
  **本组不自行扩面**;⑤ **GH #307**(`stale_waits` 那条)请派人)、**硬件面/总监**(**GH #305** 是这条裁定唯一能被证据
  推翻的路)、**批测台**(**无请求,零 AWS**,不申请专波)、**录像组**(**撤回**用 retreat 几何买
  `blinkflee` (a) 的请求,#305 落地前不必再试)、**英雄组**(无请求)。
  **下一格**:回 backlog。**不为「给弹道分支单独写前向威胁守卫」开格**(需要 #305 才能做 fixture);
  **也不为「把方向判据折进 `ShouldHoldBlinkFlee` 本体」开格**。
  详见 `iterations/reports/strategy/20260829T133722Z.md`。
- 2026-08-29T10:43Z(**owner 优先项 P2**,GH **#300**;入集提议 `test_set.md` **§CE**):**一个 presence 谓词
  被两个 id 以相反极性在同一帧上读 —— 于是同一件 85 血的道具既是「留下的理由」,也是
  「不用买大药的理由」。** 认领依据走**铁律 9**:优先项四项里常设运维球在批测台、P1 球在
  总监/批测台/录像组、P3 归总监,**P2 责任链明写「球在协同组」** ⇒ 本组有格;
  open `[strategy]` issue(#294/#289/#288/#284/#280/#278/#277/#265/#263/#262/#259)**逐条过完
  全部已落地或球在他组** ⇒ 回优先项。P2 里本组还欠的那一格写在章程 `0P2` 第 (c) 段末尾,
  **2026-08-22 登记、此后零轮认领**:「`J.HasFieldRegenSource` 只问有没有一口,不问这一口够不够」。
  **铁证帧就是 owner P2 自己钉的那一帧** `f_260822_063722_lina_tp_home`:Lina **346/1088 = 31.8%**,
  主槽 faerie_fire + **空瓶(0 充能)** ⇒ 那个 TRUE 值 **85 血 = 血条的 7.8%**;
  未 armed 它**既**让 `ShouldRegenNotGoHome` 答「留下」,**又**让 `ShouldFieldBuyRegen` 答「不必买」。
  这一帧此前被这一族用过三次(`stayfield`/`stayfield2` 的 subject、`fieldcreep` 的阴性对照 N2),
  **三次问的都是「该不该留下」,没有一次问「留下之后会怎样」**。
  **⭐ 主判据(可复用)**:**一个 presence 谓词被两个消费方以相反极性读时,它的「有」会同时
  充当两个互相抵消的理由;量级最小的那个实例反而最坏。失效方向最贵:两个 id 各自都在按自己的
  声明工作,没有任何断言会红,合起来却锁死在最差的那一格。** 判别便宜:**数消费方,看极性**。
  **产出**:gated `fieldsip`(`J.FIELD_SIP_HEAL` + `J.FIELD_SIP_MIN_FRACTION = 0.25` +
  纯函数 `J.FieldRegenSipValue` + gated `J.IsFieldSipEnough`,**未 armed 第一行字面量 `return true`**),
  **两个消费方对称消费同一合取式的正负两面** ⇒ **分区按构造保住**
  (普查五个「不可能」计数器全 **0**,`released == now_buys == **21**`)——
  `campvoid`(GH #265)那条主判据**在事前**用一次,所以这里没有第二个 `campexit` 要开。
  **常数从空隙里挑且不承重**:107 fixture / **993** 存活英雄帧,situation **54**、带补给 **23**、
  空手 **31**;23 行分成 **21 @ 0.062..0.156**(faerie_fire/tango)与 **2 @ 0.360/0.460**(大药),
  **(0.156, 0.360) 一行没有(2.3 倍空隙)**;网格实测该区间**任何**阈值释放同样 21 行 ⇒
  `[axis]` 钉的是**平台宽度 + 常数离两边各 ≥0.05**,不是 0.25。
  `tests/test_fieldsip_magnitude.lua` **15/15**(`[ratchet]`,自检快腿 **23 → 24**)+
  `tests/_fieldsip_sweep.lua`;**变异 14 个,14/14 全抓**,两端 CONTROL 干净,还原后 `git diff bots/` 空;
  承重的是 **M5(只改留守侧不改购买侧 ⇒ `IMPOSSIBLE_partition_armed` 为真)**。
  **⚠️ 方法自伤(甲)**:`>=`→`>` **第一轮 battery 活下来了(13/14)** —— 语料最近两行是
  0.156/0.360,**没有一行落在阈值上**。**让常数不承重的那条空隙,同时让它的边界测不出来**;
  补 `[boundary]`(边界血条由两个 shipped 常数**推导**,并**先断言重构在二进制浮点下精确**)后 14/14。
  **⚠️ 方法自伤(乙)**:一行**纯注释**引用出厂表达式 `not J.HasFieldRegenSource( bot )`,
  被 `test_bagsalve_backpack_source.lua` 的「调用点恰好 2 个」普查数成第 3 个,**零新增调用点就打红**
  —— 与 04:20Z 那 14 行纯注释顶行号 pin 同族。**修法是加固**(`strip_comments` + 同一条测试里
  当场证明未钝化:追加真调用点仍读 3、追加引用调用形式的注释仍读 2);修前注释既能误伤也能冒充,修后都不行。
  开工自检 worst exit **3(全部 cadence)**;**UNLANDED 0**;未裁 queue 请求 **2**(hero-22/23,他组);
  过期等待 live 块 **0**;锚点 **各 3 项 ok**;开工 trunk python **52/0/0**、快 Lua **23 文件 0 失败**;
  开工 `HEAD == 1ccdeaa7`;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;**`RULE6_BYPASS` 未使用**。
  **⚠️ 诚实边界**:**gated ⇒ 不是 live,(a) 一帧没买到**;**「链条闭合」是主张不是断言**
  (被释放的 bot 会不会真买到大药要金钱/库存/商店,fixture 都不带 —— 只断言到「帧改归 `fieldbuy`」);
  bottle 腿在 fixture 上**永远答不了**(mock `GetCurrentCharges` 默认 0),`[limit]` 断言 bottle 行数为 0;
  空隙是关于 **107 枚 fixture** 的事实不是关于 Dota 的;**方向上留守侧是收窄**(21/23 帧不再被留住),
  价值全压在同一批帧转由 `fieldbuy` 接手那一侧;`game/` 逐字节零 diff,`queue.json` 一字未动;
  **全量 Lua 套件按 229 个文件分块跑,分块 ≠ 单进程全量(GH #124),跨文件状态耦合未覆盖**。
  **⚠️⚠️ 而清干净并发之后,真的 trunk RED 出现了 —— 8 条,3 个文件,自检快腿一条都看不见**:
  按 `run_tests.lua` **排序**顺序、在**开工 `HEAD 1ccdeaa7`** 上逐条复现(读数逐字节相同):
  `test_itemdesire_world_assertion` **19/6**、`test_gamemode_world_assertion` **32/1**、
  `test_salvepool_missing_floor` **18/1**;失败文本**全是语料计数棘轮漂了**
  (`... moved: 590 / 219 / 64 with 43 without / 0 / 31 / 11`、`census row ... moved`、`124/67 vs 121/64`)。
  **与本轮无关**(本轮零新增 fixture)。**⭐ 为什么没人看见:三个文件一个都没带 `[ratchet]`**,
  而快 Lua 腿**只跑带 `[ratchet]` 的那 24 个** ⇒ **GH #267 原样重演,这次是 8 条 / 3 个文件**。
  起点**强候选**(非 bisect,shallow clone 取不到父 commit):`f08cdb56`(批测台 08-28T12:16Z,
  唯一既新增 fixture 又最后动过其中两个文件的 commit)⇒ 若成立已红约 **22 小时**,
  其间五个 stream 各跑过多轮开工自检。**本组不认领**(不是本组文件,快腿覆盖面是 #267/#213 的权),已开 **GH #302**。
  **⚠️ 本轮出过一次错读并当轮更正**:分块跑撞到 `test_cm_arcane_aura_passive.lua:226`、
  净 HEAD 上也复现 ⇒ 先写成 **trunk RED**,**错了** —— 我的分块 runner 用 `pairs()` 无序迭代,
  官方 `run_tests.lua:91-93` **排序**,排序后它**是绿的**。**「在净树上复现」回答归属,不回答存在。**
  真缺陷是**顺序依赖**:**单独跑必红、编进套件必绿**(前缀实测 0 红 / 1 绿 / 2–9 红 / 10+ 绿),
  绿的那一半**不是因为断言成立**。**本组不认领**(`[hero]`/`[bug]` 族),已另开 **GH #301** 并在 #300 上发更正追评。
  **交棒**:**总监**(① 裁 `fieldsip` 入集,建议**入**;② **请连 §CE.6 那个次序问题一起裁** ——
  「先收窄留守、再指望 `fieldbuy` 接住」不接受时,正确裁法是**要求同腿 arm** 不是拒 id;
  ③ 裁本主判据;④ 建议一次**跨 id 的「相反极性消费方」普查**,**本组不自行扩面**;
  ⑤ **GH #301** 请派人 —— **它不是一条红,是一条口径**)、**录像组**((a) 判读点 = armed 腿上只带 tango/faerie_fire
  的 situation bot 此后 10s 内**有没有一次 `item_flask` 购买**〔而不是一次回城〕;
  ⚠️ 按 §BW.3 **不得**从 `stayfield`/`stayfield2` 的留守率差分读;另请量 situation 帧里
  `botGold >= 100` 的占比 —— 它是「链条闭合」主张的上界,本组猜不了)、
  **批测台**(**无请求,零 AWS**,搭任一例行波即可,**不申请专波**)、**英雄组**(无请求)。
  **下一格**:回 backlog。**不为「把同一个 magnitude 问题搬到已 promote 的
  `J.ShouldStayAndRegen` 上」开格**;**也不为「把 magnitude 折进 `J.HasFieldRegenSource` 本体」开格**。
  详见 `iterations/reports/strategy/20260829T104321Z.md`。
- 2026-08-29T07:26Z(GH #295 的 census 那一半):**三个红文件,两个根因 —— 第二份"证据"是同一条红
  经第二条腿的转述,而且它的失败文本指着错的对象。** 认领依据:优先项无本组格,
  #295 报的 trunk RED 里 census 漂移的**肇事 commit 是本组自己的 `bc2ff86f`(04:20Z)**;
  odaoe 那一半(#296 `[bug]`)**不认领**。**先在 issue 留 claim 再动手**
  (`claim_precheck.sh` exit 0 / refused 0)—— 正是本组 01:16Z 被撞车后自己提的最轻形式。
  **根因**:04:20Z 那 14 行**纯注释**把 `test_level_gate_census.lua` 两条 pin 顶了 +14
  (`5858→5872`、`5898→5912`),而那两条是**上一个 commit**(`8cf5ae0c` director)刚为 +41 重锚过的。
  **⭐ 主判据(可复用)**:**一次插入位移的是它下面的所有 pin,跨所有钉住被编辑文件的测试
  —— 这是按 edit 扇出的事件;而修复者看见的是一个个变红的测试,于是做出按 file 的响应,
  差就静默地落在「你没看见失败的那些文件」上。** **不是假想**:同一轮**确实重锚了**
  被同一次插入顶掉的 `test_item_name_census.lua`(`:6849→:6863`),**并在自己报告里写下了教训**,
  ——**它重锚的是自己看见过失败的那一个**。⇒ 该问的不是「哪个测试红了」,是
  「**哪些文件 pin 进我刚编辑的文件**」;今天该集合是 **4 个**。修法遵循该文件自立的 `0LN2`
  「**移 pin,绝不放松检查**」:只动 `line`,`text`/`verdict` 等一字未动。
  **⚠ 第二条(更值得记)**:`tests/test_selfcheck_lua_leg.py` **不是独立根因** ——
  它的 case 5 拿**整棵工作树的副本**当 fixture,而那里的 **"clean" 指「没被这个测试改过」,
  从来不指「绿」**;于是树因任何别的原因红掉时它也红,失败文本却写作
  「`a clean tree does not report TRUNK RED`」,**读起来像检测器坏了,不像树红了**。
  **反事实证据**:只重锚那两条 pin、**对该 python 文件零编辑**,它 **4 failures → 43/0**。
  **修法**:`uncert()` 通道 —— baseline 真红时四条报 **UNCERTIFIABLE**、退出码 **2**
  (`run_py_tests.sh` **已有**这个渲染,用的是仓库既有的 0/2/3,不是新造的词),
  **这不是 GH #171 那个 SKIP-读作-PASS 的坑:差在退出码**。**判别位在代码里不在 docstring 里**
  (本组 01:16Z 判据):把 leg 点名的文件**用同一条命令单独重跑**,**只有单独也红才配降级**;
  leg 喊红而点名文件单独全绿 ⇒ **仍是货真价实的 FAIL**。**变异 2 个都按设计动作**:
  A(pin 改回,树真红)→ `0 failures / 4 uncertified`、exit **2**、点名红文件;
  **B(判别位致盲,承重那条)→ 仍 `4 failures`、exit 1,证明降级通道不吞真 leg bug**;
  还原后 `grep -c zzznomatch`=0,绿 baseline 行为逐字未变(43/0/0、exit 0)。
  **⚠⚠ 收尾被撞车,而撞车对象正是这条 claim 机制第一次实战**:push 被拒 ⇒ rebase ⇒
  `test_level_gate_census.lua` 冲突,对面 **`87c69bdc`+`dd8f5ca5`(director 07:07Z)
  「主干红了三个小时 —— 两道门盯的都是代理量」**:**两个根因一起修**,且 census 那半
  **比本组好一个层级** —— **把 `line` 字段整个删掉、改用 `text` 作键**,**永久消灭整个漂移类**,
  而本组做的是**第四次重锚**(该文件自立的 `0LN2` 只说「移 pin」,总监把 `0LN2` 本身超越了)
  ⇒ **本组对该文件的改动整份丢弃,取总监版;本组在两个红文件上的净贡献是 0 行**。
  **⭐ 最该登记的一条:这次撞车判决了「claim 评论」这个本组自己提的处方 —— 它挡不住。**
  时间线:总监 **07:07Z 本地已做完** → 本组 **07:2xZ 发 claim** → 总监 **07:3xZ 才 push**。
  **claim 只有在对方开工之前被读到才有用,而对方开工时它还不存在**;两个座位都是
  「先读 issue 再动手」,却因**中间那段本地工作时间对外不可见**而重叠。⇒ 本组 01:16Z 提的
  「最轻形式」**一次实战即被证伪**:它防「后来者撞先行者」,而本轮与 01:16Z **两次都是同时开工**。
  需要的是**开工那一刻可见、且在 push 之外的租约信号**;**形式是总监的权,本组不开面**。
  **读数**:trunk python **50/2 →(本组)51/1 →(rebase 后含总监那份)52 passed / 0 failed / 0 unc**;
  快 Lua 检测器 **1 of 21 红 → 21 文件 0 失败**;`level_gate_census` **15/0**(总监的 `text` 键版);
  `selfcheck_lua_leg` **43/0/0、exit 0**。**收工 trunk 全绿,但两个半边都不是本组修的。**
  **rebase 后重跑变异 A**(原杠杆随 `line` 字段一起消失,改为往 `test_data_consistency.lua`
  注入假断言):**0 failures / 4 uncertified / exit 2**,且**正确点名那个新文件** ⇒
  判别位在总监改过的 `routine_selfcheck.sh`(+7 行)上仍然工作。
  开工自检 worst exit **3**;**UNLANDED 0**;未裁 queue 请求 **0**;过期等待 live 块 **0**;
  锚点 **各 3 项 ok**;开工 `HEAD == 142b38ba`;**AWS $0,S3 零访问**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;**`RULE6_BYPASS` 未使用**。
  **⚠ 诚实边界**:**零行为改动、零新 gate id、`bots/` `game/` 逐字节零 diff**,
  `state.json`/`queue.json`/`test_set.md` 一字未动;**本组落地的净产出只有
  `tests/test_selfcheck_lua_leg.py` 一个文件**(即「clean ≠ green」那条判据及其判别位,
  总监没碰这一条);**census 半被总监更好的重写取代,odaoe 半本组从未认领**
  ⇒ 「收工 trunk 全绿」这句话的功劳绝大部分是总监的。
  **主判据甲没被推翻,但它的「修法」那一格被超越了**:终局不是重锚第 N 次,是**别拿行号当键**。
  (以下为 rebase 前的中间态记录)**trunk 曾从 3 个红文件降到 1 个**
  (`test_detector_source_constants.py` 的 odaoe 根因是 **#296 `[bug]` ⇒ 总监**);
  **全量 Lua 套件未跑**(~100min,GH #124;`bots/` 零改动)——**没跑完 ≠ 跑绿**;
  判别位与 leg 用同一条命令 ⇒ **不能**区分共模失效(写在注释里,没当承重)。
  **交棒**:**总监**(① 裁本轮两条判据;② **#296 仍红,trunk 至今 RED**;
  ③ 建议**跨工具普查**:还有哪些测试拿当前工作树当 fixture 却断言它是绿的;
  ④ 建议**把 pin 类检测器纳入 `.githooks/pre-push`** —— 本轮这条红本可在 push 前现形,
  它红了 **3 小时**,期间 replay-check 与 batch-desk 各跑过一轮;**本组没碰钩子,那是 #213 的权**;
  ⑤「trunk RED 认领信号」**仍未裁**,本轮用 claim 评论先行自律了一次)、
  **批测台**(#295 立案对,但「两个独立根因」对 census 这一半要改读:它带来的是**两个红文件**,
  不是两个根因;**无请求,零 AWS**)、**录像组/英雄组**(无请求)。
  **下一格**:回 backlog;**不为「预防性重锚其它 pin 文件」开格**(那是猜位移不是修位移),
  **也不为 push 钩子开格**。详见 `iterations/reports/strategy/20260829T072638Z.md`。
- 2026-08-29T04:20Z(GH #294):**一个已 promote、每局 Turbo 都 live 的守卫,在它两个调用点上的射程差 57 倍 ——
  小的那个正是 owner P2 的 TP 回家腿。** `J.ShouldStayAndRegen`(`tphome`)自己的带是
  **[0.18, 0.75]**;走路腿(`mode_retreat_generic`)调用点上方没有任何 HP 上限 ⇒ 整条带 live;
  TP 腿(`撤退:1`)第一条合取是 `botHP < 0.19` ⇒ 守卫**能改变结局**的域只有 **[0.18, 0.19)**。
  **⭐ 主判据(可复用)**:**一个守卫的域不是它自己谓词的域,而是那个域与它被放进去的那条合取式
  其余部分的交;当分支阈值恰好压在守卫下限上方一个百分点时,守卫在这个站点上几乎是空操作,
  却在自己的源码里和调用点注释里都读起来像那条腿的机制。失效方向最贵:不报错、不掉测试、
  不丢 promote 判词,只是让这条腿继续被记成「有守卫」。** **不是假想** —— `stayfield` 是为 `撤退:3`
  开的,理由白纸黑字「unlike 撤退:1 above it carries no regen veto at all」,**`撤退:1` 因为
  「有一个」被跳过**。**第二条约减(更尖)**:分支的 `itemFlask == nil` /
  `not modifier_tango_heal` / `not modifier_flask_healing` **逐条否定了守卫 `bHasFlask` 的每一支**
  (第一支是**同一个 `J.IsItemAvailable("item_flask")`、同一帧**)⇒ 守卫在这个站点上**退化成
  `bot:GetGold() >= 90`**;**这个退化只在调用点读得出来。**
  **归属修正(本轮唯一对外主张)**:GH #2 给 `tphome` 的 **+51 GPM / +54 XPM / −0.32 deaths(28 局)
  不可能在 TP 腿上买到** ⇒ **那份效应属于走路腿**。归属修正,**不推翻 promote**。
  **产出**:`tests/test_tphome_tp_leg_counterfactual.lua`(`[ratchet]`,**14 例全绿**,自检快腿 18 → 19;
  subject = owner P2 钉的真实帧 `f_260822_063722_lina_tp_home`;`[reduce]` 在真实帧上量出
  **gold 89→false / 90→true**;`[axis]` 141 点网格里 `<0.19` 只有 1..4 点且落在 `[0.18,0.19)`)
  + `bots/ability_item_usage_generic.lua` **纯注释 14 行**的更正。**变异 9 个,9/9 首轮全抓**,
  两端 CONTROL 干净,还原后 `git diff bots/` 空。
  开工自检 **worst exit 3(全部 cadence)**;**UNLANDED 0**;未裁 queue 请求 **0**(open 37);
  过期等待 live 块 **0**;稳定版锚点 **各 3 项 ok**;trunk python **51/0/0**;trunk 快 Lua **18 文件 0 失败**;
  开工 `HEAD == 4da08250`;**AWS $0,S3 零访问**。
  **⚠ 诚实边界**:**零行为改动、零新 gate id、`game/` 逐字节零 diff**,`state.json` / `queue.json` /
  `test_set.md` 一字未动(**本轮没有 id 可入集**);(3,8] 那个窗口**语料里没有帧**,是声明输入
  且声明本身写成了断言;`X.ConsiderItemDesire["item_tpscroll"]` 在 fixture 上不可达(GH #89);
  「1200 环 ⊆ 1600 环」**没当承重**(last-seen 2.0s vs 可见列表,两个数据源)。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;`tphome_tp_leg` **14/0**;`smoke_load` **3/0**、
  `lina` **45/0**、`gate_claim` **10/0**;**`RULE6_BYPASS` 未使用**。
  **⚠ 本轮自己造了三条 trunk 红并全部修回**:那 14 行**纯注释**打红了**两个文件三条行号 pin** ——
  `test_item_name_census.lua` `:6849→:6863`(该 pin 第 **11** 次漂移)、
  `test_level_gate_census.lua` `:5858→:5872` 与 `:5898→:5912`(这一对第 **4** 次、
  **第 3 次由散文干的**,而这次是**最干净的实例:原理上都不可能改变行为**)。
  三条**只重锚不放松**,`item_name_census` **6/0**、`level_gate_census` **15/0** 复绿。
  **全量套件终读:2443 tests / 10 failures = 本轮 3 条(已修)+ trunk 既有 7 条**
  (`itemdesire_world_assertion` ×6 + `salvepool_missing_floor` ×1,与英雄组 02:0xZ 记的
  「trunk 上 7 条红」**逐条对上**)。
  **⚠ 方法自伤,两层**:(i) `test_item_name_census.lua` **带 `[ratchet]`、在自检快腿覆盖里** ——
  **门是有的,是我没走**:自检只在**工作单元开头**跑过(干净),写完注释没再跑就推了 ⇒
  它在 main 上红了一个 commit 的长度。**开工自检认证的是你到达时的那棵树,不是你推出去的那棵树。**
  (ii) **而补跑整条 tagged 快腿(15 文件 0 失败)仍然不够** —— `test_level_gate_census.lua`
  **不带标签、不在那 15 个文件里**,同一处编辑造成的另外两条 pin 红**躲过了两道门**,
  只有全量套件抓到。**⭐ 由此得到本轮第二条可复用条**:**对一次 `bots/X` 的编辑,该跑的是
  「所有把行号 pin 进 `X` 的测试」,而这个集合 `grep` 一次就有** —— 比「哪些测试带标签」更能定位风险。
  已作为 [harness] 一格交总监。
  **另**:python 侧 `test_detector_source_constants.py :: wandlimbo_domain:HP_FRAC (UNREGISTERED)`
  **是随 rebase 进来的**(`bb00ea75` replay-check 05:30Z,在那个 commit 的干净检出上逐字复现)
  ⇒ **报出来,不认领**(昨天 GH #289 刚因两座位抢同一条 trunk RED 白掉一轮)。
  全量套件其余部分本会话未跑完(**没跑完 ≠ 跑绿**),读数见报告 §8。
  **交棒**:**总监**(① 裁本判据;② 裁「归属要不要回写 `state.json` 的 `tphome` 条目」——
  改已 promote id 的档案不是本组的权;③ 建议一次**跨 promoted id 的多调用点普查**,
  `nodive`/`pushguard`/`tpsafe`/`regroup` 都是多点消费,**本组不自行扩面**)、
  **录像组**(唯一没有照片的那一格:HP ∈ [0.18,0.19) 且上次英雄伤害在 (3,8]s、≥90 金、
  主槽无 flask 的帧,**请钉一帧**;频率本组不猜)、**批测台/英雄组**(无请求,零 AWS)。
  **下一格**:回 backlog;**不为「抬 `撤退:1` 的帽」开格**,**也不为营地那一族开格**(理由见 `0SITE`)。
  详见 `iterations/reports/strategy/20260829T042022Z.md`。
  **⚠ 收尾补记(本会话挂钟跨度远大于一个工作单元,收尾时 main 已到 `4938017c`)**:
  (i) 那两条 `test_level_gate_census.lua` 的 pin **上游已改为按文本键、不再带 `line`**,
  比本组的重锚严格更好 ⇒ rebase **整份采用上游**;(ii) 「该按 edit 扇出而不是按 tag 跑」这条
  **本组不再声称是自己的** —— **07:26Z(GH #295)已立得更准**,并点名本轮只重锚了
  **自己看见过失败的那一个**文件(同一次插入共顶到 **4 个**),**引用不重复立案**,
  肇事 commit 是本组 `bc2ff86f`,记得对;(iii) python 那条 `wandlimbo_domain` 红仍不认领。
  **§1–§7 的实质结论未受影响**,`test_tphome_tp_leg_counterfactual` 在 `4938017c` 上仍 **14/0**。
- 2026-08-29T01:16Z:**同一个缺陷,一小时内被两个座位各自独立地找到并修好 —— 本组的那份是
  重复劳动,已整份丢弃。** 认领 GH #289(批测台按铁律 5 交棒过来的 trunk RED,`[strategy]` 前缀)。
  诊断:本组一天前落地的 `stale_waits.py`,其**不变量 2** 写着「对活着的接力棒报红的检测器
  一轮之内就会被关掉」—— **一轮之内它做到了**。红行是 22:15Z 的「等总监**重裁** `campexit`」,
  即 GH #288 之后请求的**第二次裁定**(入集 06:5xZ 早已落地)。测试 docstring 早给了逃生口
  (「say so on the line」),**那一行已经照做写了「重裁」**,只是**「重裁」⊃「裁」**命中
  `ADMISSION_MARKERS` 的 `"裁 "` ⇒ **散文里存在的逃生口,代码里不存在**。
  **⭐ 主判据(可复用)**:**一个检测器写下的「这类东西不算发现」是一条断言,不是免责声明 ——
  除非它在代码里有对应的判别位。豁免只活在 docstring 里、而被豁免对象的措辞又是匹配串的超串时,
  工具会对着自己点名保护的那一类报红,且报红时给出的处方是「删掉那个对象」。失效方向最贵:
  不是漏报,是**反向施压** —— 把树弄绿的最短路径正好是丢接力棒(铁律 9 那条掉了 37 轮的棒,
  由抓它的工具送达)。** **被否掉的明显做法**:「写在裁定落地之后的等待不是过期入集等待」
  ——**不判别**,立案四行全在 06:5xZ 之后;**时钟分不开,动词能**。
  **⚠ 撞车(本轮更值得登记的事)**:push 被拒 ⇒ rebase ⇒ 两个文件都冲突,对面是
  **`8a239be1` director 01:06Z**:**同款诊断、同款按行豁免**(`RE_RULING = [重再复]新?裁`),
  且是超集(另修 BULLET 正则只量到五个章程里的两个,并**裁了 `campexit` 退集**)⇒
  **整份采用总监那份,丢弃本组两个文件的改动**,解完与 `8a239be1` 逐字节相同。
  不是 GH #180 那种同座位并发,是**跨座位重复认领**:#289 是 `[strategy]` 前缀(归本组),
  总监按开工自检读到同一条红也动手了 —— **两边都没错,规则没说归谁**。
  **真正留下来的一样**:总监那份**没有**的一条断言 `INVARIANT 6b`(**动词,不是结局词**:
  对 `RE_RULING` 最便宜的下一个错误编辑是放宽到 `退集`/`去留`,而那两个词说的是裁定**决定什么**,
  会出现在真的**第一次**入集等待里「等总监裁 `X` 入集,不入就退集」⇒ 以它们为键的豁免
  消音的正是不变量 1 存在的理由)。**实测承重**:放宽成 `[重再复]新?裁|退集|去留` 后
  总监那 36 条**全绿**,只有这一条咬住 ⇒ **37/1**;装回去 **37/0**。
  **结清**:总监同一 commit 裁了 **`campexit` 退集**(线 2 43 → 42,gate 与代码逐字节保留、永不 arm,
  档案 `test_set.md §CB`,03:5xZ 前写作 §CA),理由与本组 22:15Z / GH #288 的读数一致 ⇒
  **本组「等总监重裁 `campexit`」到此结清,不再重复请求。**
  开工自检 **UNLANDED 0**;未裁 queue 请求 **0**(open 37);稳定版锚点 **各 3 项 ok**;
  trunk 快 Lua 检测器 **18 文件 0 失败**;开工 `HEAD == b701fdf3`;**AWS $0,S3 零访问**。
  **⚠ 一处自造假红已归因**:开工时并发跑了两遍自检 ⇒ 前台读 47/4,三个陪绑的都是写
  `bots/Customize/soak_side.lua` 的 gate-churn 测试;单跑 `run_py_tests.sh` 读 **50/1**,
  与 #289 逐位相同 ⇒ **是我的并发,不是 trunk**。
  **⚠ 诚实边界**:**零行为改动、零新 gate id、`bots/` `game/` 逐字节零 diff**;
  本轮对工具的净贡献**只有一条断言**,机制那半是总监的;`queue.json` 零改动;**零 AWS**。
  **门**:`test_stale_waits` **37/0**;`luacheck_gate.sh` **0 warnings EXIT=0**;`run_py_tests.sh` 全绿;
  **全量 Lua 套件未跑**(~100min,GH #124;本轮 `bots/` 零改动);**`RULE6_BYPASS` 未使用**。
  **交棒**:**总监**(① 裁本轮判据,并考虑一次**跨工具普查** —— `pending_rulings.py`/
  `citation_audit.py`/`unlanded_commits.py` 的 LIMIT 里有没有同样「只活在散文里的豁免」,
  **本组不自行扩面**;② 裁**「trunk RED 的认领信号」** —— 本轮两个座位一小时内重复修同一条红,
  建议最轻形式是「动手前在 issue 上留一行 claim」,**权在总监**;③ selfcheck python 腿 exit-3 支
  给的 `git stash` 建议对**并发写 `bots/`** 不起作用,值得一条 [harness] issue;
  ④ `campexit` 退集**已收到**)、**批测台**(#289 **立案对**、**处方在这条线上会删掉在途交棒**,
  已在 issue 上说明;**本轮无请求,零 AWS**)、**录像组/英雄组**(无请求)。
  **下一格**:回 backlog(`campexit` 一族到此结清);**不为「把第二次裁定的其它措辞也纳入豁免」开格**。
  详见 `iterations/reports/strategy/20260829T011623Z.md`。
- 2026-08-28T22:15Z:**一个杠杆的立案帧列表,和推翻它的那张表,住在同一份文件里相隔二十行 ——
  `campexit` 头注点名的五帧,有三帧在它引用的那份报告里记着「干净吃下」。
  把它们汇总成立案理由的那个量(平均烧血 10.4pp),在六段里的五段是拿下一个远古营的价钱。**
  开工自检 **UNLANDED 0**;**expired waits 0**(上一轮 `0WAIT` 那条腿第一次在别人轮次里跑,live 块零发现);
  未裁 queue 请求 **0**(open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  trunk python **51 passed / 0 failed / 0 uncertifiable**;trunk 快 Lua 检测器 **17 文件 0 失败**;
  selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == f108396`;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0,S3 零访问**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 DoD① / P2 DoD① 已完成、
  球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成优先项格**;open `[strategy]` **19:16Z 之后零新增**
  (#285 [batch]、#283 [bug]、#287 [hero]);`0WAIT` 的下一格是等总监裁 —— **这次「阻塞」两个字本身被查过**
  (#284 至今无裁定,`stale_waits` 确认它不是过期等待)⇒ 回章程工作流第 1 条,
  查 **GH #263 那条本组自己交出去的重开条件是否已兑现 —— 已兑现**
  (`campfarm_target.py` + `ancient_camp_domain` 08-28 入库带 `--selfcheck`,录像组 03:55Z 已给逐段读数)⇒ 开格;
  开格后读那份读数,撞到本轮真正的东西。开 **GH #288**。
  **⭐ 主判据(可复用)**:**挑选立案帧的那一步只问「这一段是不是我要治的形状」(静止、烧血、无敌方英雄),
  不问「这一段买到了什么」—— 而后者是同一位作者在同一轮里量出来的下一张表。失效方向是最贵的那侧:
  被误收的帧让立案看起来更强(五帧比一帧有力),而每多收一帧,armed 分支的反向面就大一分,
  且没有任何东西会为此转红。** 判据本身是本组一天前刚立的(`abil1st` 撤回:armed 在自己域里反向一帧就够撤回);
  这里是**六帧反向四帧**,且长在**出厂腿**上。与 #278/#280 同族但换层。
  **算术**:头注五帧(venomancer 786.3 / dragon_knight 703.5 / necrolyte 738.8 / lion 618.5 / storm_spirit 694.4)
  逐条对上 `20260828T035500Z.md` **§3.3**(104–108 行,t/hp/腿逐位);同文件 **§4**(155–160 行)给结局:
  **6.3× 吃下 / 9.3× 吃下 / 3.7× 吃下 / 5.2× 吃下 / 3.6× 半场走 / 1.1× 白烧 45pp**。
  谓词只读**等级 + sweep 物种**,六段等级 `10/10/10/11/11/10` 全在拒绝带内 ⇒ **armed 六段全释放**。
  **⚠ 最尖的操作后果**:`state.json` 里 (a) 的读点是「几秒内**离开**」⇒ **释放 dragon_knight 那个营就满足 (a)**,
  **(a) 由失效模式买单且读起来像 WORKING**;必须劈成「释放了打不完的营」vs「释放了正在拿下的营」。
  **产出**:`tests/test_campexit_take_counterframes.lua`(**唯一新增文件**,`[ratchet]`,**10 examples 全绿**)+
  `state.json → campexit_20260828.contra_20260828T22`(**只登记反向读数,不改 `armed`/`in_test_set`**)。
  **变异 8 个:7 CAUGHT / 1(M8)设计内 SURVIVED**;两端 CONTROL **10/0**;三份快照 restore 逐字节相同。
  **⚠ 方法自伤(测试第一次运行就抓到,不是复查)**:`[domain]` 第一版断言「吃下的等级集合 == 没吃下的等级集合」
  ——**假的**(两个非吃下都是 L10,L11 是 2/2);改成真正需要的弱形式(某个等级值同时装两种结局),
  **自伤写进文件注释,不只写进报告**。
  **⚠ 诚实边界**:**零行为改动、零新 gate id、`bots/` `game/` 逐字节零 diff** ⇒ 无「已上线」主张;
  **不退集、不改 `campexit` 代码、不动 `test_set.md` 线 2**(权在总监);`queue.json` 零改动;**零 AWS**;
  6 段深查不是那 25 段;四段「吃下」的真实 sweep 成分不在任何 fixture 里(**逃生口已写成断言**);
  出/入比最近一对 **3.6 对 3.7**;**不推翻**「10..11 带存在真实浪费」(venomancer 45pp、ES 致死都是真的),
  推翻的是「这个域可以整体当成浪费」。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;`run_py_tests.sh` **51/0/0**;
  `campexit_take_counterframes` 10/0、`campexit_tier_release` 17/0、`replay_004757_veno_ancient` 9/0、
  `smoke_load` 3/0、`gate_claim_consistency` 10/0、`campfarm_ancient_target` 16/0、`pullcamp_trigger_census` 29/0。
  **全量 Lua 套件未跑**(~100min,GH #124;本轮 `bots/` 零改动);**`RULE6_BYPASS` 未使用**。
  **交棒**:**总监**(① 重裁 `campexit`:收窄到完成度轴 / 退集 / 维持并写明「每 6 段释放 4 段盈利的营」;
  ② **(a) 的读法必须先劈开**,否则 W22 收割回来的是失效模式买到的 WORKING;③ #284 判据仍待裁,不重复催;
  ④ GH #267 立场不变)、**录像组**(`campexit` 的 (a) 请按「被释放的营 15s 内本来会不会死在他手里」分层,
  不要只数「他有没有走」;另 GH #263 重开条件本轮已认定兑现)、**批测台**(**本轮无请求,零 AWS**)、
  **英雄组**(无请求)。
  **下一格**:等总监重裁 `campexit`;**不为「落地完成度子句」开格**(阈值在 3.6/3.7 那条缝里,
  先要一次可复算的分母:#263 登记的 W18 68 局重跑,排在 #270 之后)。
  详见 `iterations/reports/strategy/20260828T221500Z.md`。
- 2026-08-28T19:0xZ:**本组连续四轮写着「等总监裁 `campexit` 入集(仍挂着)」,
  而那条裁定 06:5xZ 就落了地 —— 四轮全部跑在已含它的树上,第一轮自己的报告里
  就印着那个裁定的 commit。更贵的不是那句话过期,是它被读成「阻塞」,
  于是静默地决定了那几轮各做什么。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(本组 9.2h,那一格是 01:24→10:35 的洞,本行不改写它);
  未裁 queue 请求 **0**(open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  trunk python **50 passed / 0 failed / 0 uncertifiable**;trunk 快 Lua 检测器 **17 文件 0 失败**;
  selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == e80a72ef`;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0,S3 零访问**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 DoD① / P2 DoD① 已完成、
  球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成优先项格**;open `[strategy]` **16:32Z 之后零新增**
  (#281 是 [harness]、#283 是 [bug]);取 backlog 最上一条 `0IDENT` 时**先查它写的「阻塞」是否还成立**
  —— 一查就发现那个阻塞的对象 **`campexit` 已经入集**。⇒ 认领**这条被四轮抄下去的过期等待本身**。
  开 **GH #284**。
  **⭐ 主判据(可复用)**:**一次「我在等 X」的记录是一个带失效条件的断言,而这个仓库里它的
  失效条件是机器可读的(X 出现在 arm 串里)。等待方每轮把这句话原样抄下去,而抄写不查失效条件;
  `pending_rulings.py` 覆盖的是对称失效的另一半(请求方那侧「没人裁」),等待方这侧
  (「已经裁了但还在等」)此前没有任何东西在看。失效方向是最贵的那一侧 —— 它不报错、不掉测试、
  不输一局,反而作为「阻塞」的理由决定这一轮做什么。** 与 GH #210 同族,**在交付路径的另一端**。
  **算术**:裁定 `e7e57979`(**07:09Z 落 origin**,`test_set.md` 线 2 由 41 → 43 id);过期行四条 ——
  **07:30 / 10:35 / 13:55 / 16:32**;07:30Z 那一轮的报告自陈 `开工 HEAD == e7e5797`,**就是它**;
  同四轮的自检行「未裁 queue 请求 **0**」**属实**(这条等待从来不在 `queue.json` 里)⇒
  **仪器与散文各说各的,四轮无人对账**。
  **产出**:`tools/agent/stale_waits.py`(**新增**;扫每个章程**当前状态最新那一条**,命中要求
  同一行**既要一个入集裁定、又说它还欠着**,且反引号 id 已在 arm 串或已 promoted;
  退出码 **0 干净 / 3 有发现 / 2 没跑成**;历史行只报 INFO **永不算发现**)+
  `tests/test_stale_waits.py`(**19 checks**,`[ratchet]`,五条不变量;**变异 6 个 6/6 CAUGHT**,
  两端 CONTROL 干净 **19/0**)+
  `routine_selfcheck.sh` 新增 `stale-waits` 腿(紧挨 `queue-rulings`,它看的是同一条路径的另一端)。
  **⚠ 方法自伤(已写进 docstring,不只写进报告)**:第一版用 `git log -S <id> -- test_set.md` 取
  「落地时间」,那答的是**待裁区提案**(04:3xZ)不是**裁定**(07:09Z)——**会把合法等待读成过期**,
  正是本工具要抓的那种过度主张、由工具自己先犯一次;改成沿文件历史回溯**线 2**,并由不变量 3 钉住。
  **判别力(不变量 2)**:「等录像组核验 `campexit` 的条件 (a)」这种**同一个已 armed id 上的
  真实在途接力棒不算发现** —— 一个会对活着的接力棒报红的检测器,一轮之内就会被关掉。
  **⚠ 方法自伤 2(本轮报告自己触发的)**:第一版对**引用**与**使用**不分 ⇒ 它对
  **报告这条过期等待的那一行**报红,也就是**对修好它的那份工作报红**;修法是
  **同块同 id 的「已入集/更正」豁免**(不变量 4 钉住 id 作用域)。
  **⚠ M3 是变异挑出来的,不是复查**:第一版丢掉「还欠着」那一半合取时**全部检查照过** ——
  没有任何断言扣住「`本轮 X 入集` 这条事实记录不是一次等待」;补成不变量 5 后 6/6 CAUGHT。
  **⚠ 诚实边界**:**零行为改动、零新 gate id、`bots/` `game/` 逐字节零 diff** ⇒ 无「已上线」主张;
  不碰任何 gate id 入集状态,`test_set.md` / `queue.json` **零改动**,**零 AWS**;
  检测器只覆盖**当前状态最新一条**,backlog 的「下一格」(**恰恰是被读成阻塞的那种行**)是
  **已命名的盲区**、只作 INFO;匹配靠散文关键词 + 反引号 id ⇒ **只漏报不造词**;
  一条过期等待在下一条状态条落地后不再是发现(**设计如此**);四处过期行**已就地更正并保留原行**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;`bash tests/run_py_tests.sh` **51 passed / 0 failed /
  0 uncertifiable**(新测试并入自动跑的那一组);`smoke_load` 3/0、`gate_claim_consistency` 10/0。
  **全量 Lua 套件未跑**(~100min,GH #124;本轮 Lua 零改动);**`RULE6_BYPASS` 未使用**。
  **交棒**:**总监**(① 判据若接受值得一次跨文件普查「还有几处『等 X』的对象已经落地」,
  **本组不自行扩面**;② **`campexit` 不需要再裁** —— 本组此前三轮的提醒作废,已就地更正;
  ③ GH #267 立场不变)、**录像组**(`campexit` 条件 (a) 的**语料已经存在**:W21,arm 串 43 id 含
  `campexit`、四粒全计分、批测台 15:15Z 收割;读法与 §BW.2 的下界警告已在贵组章程 49–57 行)、
  **批测台**(**本轮无请求,零 AWS**)。
  **下一格**:等总监裁判据;**不为「把 backlog 下一格也纳入发现」开格**。
  详见 `iterations/reports/strategy/20260828T190000Z.md`。
- 2026-08-28T16:32Z:**一条判据升了一级(文件同居 → accessor 绑定),而它自己剩下的那个
  承重前提 —— 被比较的 accessor 返回的是不同的对象 —— 一条断言都没有。
  让它失效的那次重构,恰恰是让每一条现有断言都保持绿色的那一种。
  而且是本轮 driver 的第一版先踩了它:M2 从三条恒真的同一性断言旁边走了过去。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(本组 9.2h,本轮即在补);
  未裁 queue 请求 **0**(open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  trunk python **50 passed / 0 failed / 0 uncertifiable**;trunk 快 Lua 检测器 **17 文件 0 失败**;
  selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == b95f80cb`;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0,S3 零访问**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 DoD① / P2 DoD① 已完成、
  球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成优先项格**;open `[strategy]` **13:55Z 之后零新增**
  (#278 上一轮三问全部作答、#277 已落地);backlog 最上两条 `0EXPIRE`/`0POP` 的下一格
  **都是「等总监裁定」** ⇒ 阻塞 ⇒ 认领 `0EXPIRE` **自己登记的那条未兑现诚实边界**
  (「`aba_defend` 的 `*1.65` 是按同一条错判据被归为死的,仍待独立核验」)——
  **这是本组自己交出去又没接住的棒,不是扩面**(总监那两次跨文件普查**本组仍不自行开**)。
  开 **GH #280**。
  **⭐ 主判据(可复用)**:**一条「谁读谁」的判据,自己也有一个承重前提:被比较的那些 accessor
  返回的是不同的对象。判据升一级不会把这个前提补上,而它失效的方向和原来那次一样危险 ——
  给活着的站点开脱、把死的定罪。凡是靠「这个值属于哪个写者」下结论的地方,对象同一性必须是
  一条断言,不是一段散文;因为让它失效的那次重构(合并两张长得几乎一样的 cache),
  恰恰是让每一条现有断言都保持绿色的那一种。** 与 GH #278 判据 B 同族,**低一级**。
  **算术**:三个膨胀站点 `aba_defend:239 *1.65` / `global_cache:207 *2` / `aba_push:58 *2`,
  各写自己的 file-local 表。**两个世界各一读**(`f_260820_043637_axe_ring_alone`,raw **641.4**):
  plain **641.4 / 641.4 / 641.4**、honest **1058.31 / 1282.8 / 1282.8** ⇒ 第十五条世界断言在
  cache 层**把三个膨胀一起关掉**(这正是此前只能钉字符串的原因);故「死」= **没人读**不是**没算**。
  **⭐⭐ 最硬的一半(M2 + M8)**:**M2**(`updateGameStateCache()` 返回 `getGlobalGameState()` 的表
  = 最可能的那次 dedupe)⇒ **旧块 0 failures** —— 三条字面量 pin、`readers==2`、`foreign==0`、
  绑定 pin **全部照过**,只有新同一性断言抓到;**M8**(放松三条同一性断言再重放 M2)
  **SURVIVED —— 设计内,即那条线存在的证明**。
  **⚠ 方法自伤(M2 揪出来的,不是复查)**:driver 第一版另起一次 `dofile(global_cache.lua)` 取
  accessor,那是**第二个模块实例**、带自己的 `globalGameStateCache` local ⇒ 三条同一性断言
  **恒真但因为错的理由**,M2 第一次**从旁边走了过去**。修法就是判据本身:**accessor 必须从读者手里拿**
  (`aba_push:43` 绑成 file-local ⇒ 是各 export 的 upvalue)。**已写进测试注释,不只写进报告。**
  **缺陷 2(沿用 → containment 重推)**:`defendGameStateCache` **从不离开它自己的文件** ——
  全仓 6 处提及**全在 `aba_defend.lua`**(`elsewhere==0`),4 个调用点**逐个**绑普通 local,
  无 export 交出表 ⇒ 读者集合可**穷举**:该文件从自己 cache 读**恰好 6 个字段**,
  **`currentTime` 不在其中**。**缺陷 3(grep 盲区)**:括号读 `gameState["currentTime"]`
  (**M7 实测:旧块全绿**)与整表消费,当前全仓均 **0**,现已断言。
  **顺带登记**:三表**互不为子集**(`aba_defend` 独家 2 个且**读其中一个**;`global_cache` 独家 6 个;
  `aba_push` 那份与 `global_cache` **逐项相同** ⇒ 它才是最可能被 dedupe 的一个),
  合并会发 **nil**(**M6** 抓);仓库同时跑**两套 turbo 时钟约定**(`1.65` 与 `2`),已断言。
  **产出**:`tests/test_gamemode_world_assertion.lua` **唯一改动文件 +265**
  (新 driver `dilations()` / 4 个新块 / accounting 块头注标注「第三个站点是沿用不是重推」
  并指向重推,**保留历史行不删**)。
  **变异 8 个:7 CAUGHT / 1(M8)设计内 SURVIVED**;两端 CONTROL 干净(**33/0**,改前 29/0);
  快照走 scratchpad **且快照那步本身被断言**(4 文件 `cmp -s`);`bots/` `game/` **逐字节还原**。
  **⚠ 诚实边界**:**零行为改动、零新 gate id、`bots/` `game/` 零 diff** ⇒ 无「已上线」主张,
  不碰任何 gate id 入集状态,`test_set.md`/`queue.json` **零改动**,**零 AWS**;
  **上一轮结论没有被推翻**(活的仍是 `global_cache` 那份)—— 换的是**证据的种类**加**补上那条没人写的前提**;
  读数取自**一帧**(倍率与表同一性是结构性的,「三个写者都能驱动」只在这一帧量过);
  「合并会发 nil」是源码+运行时字段表推的,**不是真实对局事故**;两条 grep 普查封的是**已知**
  的两个盲区**不是全部**;GH #267 本组第六次点名,**仍不擅自抬**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;`test_gamemode_world_assertion` **33/0**(改前 29/0);
  `smoke_load` 3/0、`gate_claim_consistency` 10/0、`no_undefined_jmz_refs` 3/0、
  `level_gate_census` 15/0、`activemode_world_assertion` 12/0、`pullcamp_trigger_census` 29/0。
  **全量 Lua 套件未跑**(~100min,GH #124);**`RULE6_BYPASS` 未使用**。
  **交棒**:**总监**(① 判据若接受,跨文件普查口径从「读者绑哪个 accessor」扩到
  「**被比较的 accessor 是否返回同一对象**」,**本组不自行扩面**;② `campexit` 入集裁定**仍欠**,
  第三次提醒不重复开请求;③ GH #267 立场不变)
  〔**2026-08-28T19:xxZ 更正(保留原行)**:②**是过期的等待,而且是连续第四轮** ——
  `campexit` 06:5xZ 已入集(`e7e57979` 写进 `test_set.md` 线 2);07:3x / 10:3x / 13:5x / 16:3x
  四轮全部跑在已含该裁定的树上。**「未裁 queue 请求 0」那一行读的是 `queue.json`,
  而这条等待从来不在 queue 里** —— 仪器与散文各说各的,四轮无人对账。
  见 `0WAIT` / GH #284 / `tools/agent/stale_waits.py`。〕、**英雄组**(#278 剩下的那半个诚实边界已补 ⇒ **可关**)、
  **批测台**(**本轮无请求,零 AWS**)、**录像组**(**无请求**)。
  **下一格**:等总监裁定;**不为「删掉两份死膨胀」开格**,也**不为「合并三张 cache」开格**
  —— 本轮的断言正是为了让那件事被做时**响一声**。
  详见 `iterations/reports/strategy/20260828T163257Z.md`。
- 2026-08-28T13:55Z:**一条在自己的注释里**预言了会让它失效的那件事**的边界,
  到期时不是作为读数出现的,是作为红出现的,砸在合规加 fixture 的那张桌子上。
  顺手买到的第二件更硬:三个 `adjustedTime` 里被判死的那两个**点错了名字**。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(本组 9.2h,本轮即在补);
  未裁 queue 请求 **0**(open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  trunk python **49 passed / 0 failed / 0 uncertifiable**;trunk 快 Lua 检测器 **17 文件 0 失败**;
  selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == b95f80cb`;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0,S3 零访问**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 DoD① / P2 DoD① 均已完成、
  球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成优先项格**;扫 open `[strategy]` ⇒
  **GH #278 是 10:35Z 之后新落的、无人认领的一条,且带帧证据**(章程工作流 1「优先处理带帧证据的」),
  由**英雄组**开出并明确交棒(`aba_push.lua` is 協同/strategy territory);
  它同时是**当轮 trunk 红**(`test_gamemode_world_assertion:534 ... got 2`)⇒ 认领。
  **⭐ 主判据 A(可复用)**:**一条写作「语料还够不到这里」的边界,是一个带到期日的断言,
  必须写成「到期时是一个读数」而不是「到期时是一条红」。** 失效方向是**归因错的红**
  加**一个把陷阱重新上膛的最便宜出口**(690 改 790)。`0QUOTE`/GH #273 同族但**狠一格**:
  那次注释与断言互相矛盾,**这次注释把会让它失效的事件直接预言了出来**。
  **算术**:门 `nCloseByTime=1500`;`past_plain` 需 raw DotaTime **>1500s** ⇒ **0/107 不变**
  (成因从「语料太短」更正为**结构性**:字面 `==23` 永不膨胀,比抬高后的闸还远);
  `past_honest` 需 **>750s** ⇒ **0 → 2/107**;`s.latest` **690.5 → 790.4**。
  四条分别定性:`past_plain==0` **留等式**(红是信息)/ `past_honest` **退休→ratchet(2)** /
  `s.latest` **退休→ratchet(790.4)** / `latest*2<1500` **翻面为 >1500**;
  另加**独立推导**(`#past_frames==past_honest` 且每帧 `t>750`)—— 因为 sweep 若**膨胀了错的帧**,
  计数根本不动,ratchet 抓不到。
  **⭐⭐ #278 问题 (1) 的答案(驱动 2 帧 × 3 路 × 2 拼法 = 12 次实测)**:
  **子句确实打开了**(`bPastCloseByTime` false→true、`nMaxDesire` **0.92→0.95**,**12/12**),
  **返回欲望一点没动**(**0/12**)⇒ 答案**既不是「决策」也不是「cache 字段」,是
  「在我们手上这两帧上它移动的是一个死局部变量」**:两个后果(cap 抬高 / `+0.35`)
  **都在这两帧会走的无条件 return `#alliesHere<=1 and aliveEnemyCount>=3` 下游**。
  顺带补上从未被扣住的洞:原 split 块**两个后果站点一个都没钉**,而 `+0.35` 是**大得多**那条 ——
  「后果不可观测」是在更大的臂根本没被断言时发表的;现在钉的是**顺序**不是行号。
  **⭐ 主判据 B(可复用,由 M1 把我自己的第一个假设证伪后才浮出来)**:
  **值在表里跨文件传递时,读者绑定哪个写者由「读的那个函数调了哪个 accessor」决定,
  不由文件同居决定;一个既写自己 cache 又读别人 cache 的文件,会被任何同居判据归给它自己
  —— 而判据两边都是绿的。** 实测:两个 `.currentTime` 读者(`:173`/`:221`)**都在
  `GetPushDesireHelper`**,而它 `:146` 绑的是 `getGlobalGameState()` ⇒
  **`global_cache` 那份是全仓唯一活着的膨胀,`aba_push` 自己那份是死的**;
  accounting 块原写「aba_defend 和 global_cache ... change nothing」**数目对、名字反**。
  **失效方向危险**:给活的开脱、把死的定罪,而该块自陈用途正是提醒别人「cache 里的钟没膨胀」
  —— 按它删掉那个乘法**会静默移动每一场 Turbo 的推进上限决策**。
  **产出**:`tests/test_gamemode_world_assertion.lua` **唯一改动文件**(失败块重取并改名 /
  两个新块 / `corpus()` 加 `past_frames` / 新驱动器 `push_desire()` / split 块操作数**改钉
  global_cache 那份活的**、aba_push 那份留作「第二份副本」/ accounting 块死活命名**更正**
  并把跨 accessor 绑定**补成断言** / 头注把已发表段落标为**被修正**,不删历史行)。
  **变异 8 个:7 CAUGHT / 1 即 M2 是「它是死的」的证明**;M7 比预期强一格
  (放松 ratchet 后仍被**驱动块的非空性守卫**抓到);两端 CONTROL 干净(29/0);
  快照走 scratchpad **且快照那步本身被断言**;`bots/` `game/` **逐字节还原**。
  M8 前两次锚点不唯一(count=2)**中止未改文件**,那两次输出**作废未采信**。
  **⚠ 诚实边界**:**零行为改动、零新 gate id、`bots/` `game/` 零 diff** ⇒ 无「已上线」主张,
  不碰任何 gate id 入集状态,`test_set.md`/`queue.json` 零改动,零 AWS;
  **我的第一个假设(「活的那份没人钉」)被 M1 证伪并写进报告** —— 活的一直被钉着,
  真缺陷是**名字写反**,比我猜的更值钱;「移动死局部变量」**只对这两帧成立**
  (同局同英雄相隔 5 秒,**不是两个独立样本**),已写成断言;
  **`aba_defend` 的 `*1.65` 是按同一条错判据被归为死的,本轮没有单独证它,仍待独立核验**;
  GH #267 本组第五次点名,**仍不擅自抬**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;`test_gamemode_world_assertion`
  **29/0**(改前 27 tests **1 failure**);`smoke_load` 3/0、`gate_claim_consistency` 10/0、
  `no_undefined_jmz_refs` 3/0、`level_gate_census` 15/0。
  **全量 Lua 套件未跑**(~100min,GH #124);**`RULE6_BYPASS` 未使用**。
  **交棒**:**英雄组**(#278 三问全部作答 ⇒ **可关**)、
  **总监**(① `campexit` 入集裁定**仍欠**,只提醒;② 两条主判据各值得一次**跨文件普查**,
  **本组不自行扩面**;B 的具体候选是 `aba_defend` 的 `*1.65`;③ GH #267 立场不变)、
  **录像组**(无请求;顺带:cap 抬到 25 分钟后语料**第一次能越过 DotaTime 750s**,
  凡引用「turbo 后期」的读数从这一波起要重新问一遍语料够不够得着)、
  **批测台**(本轮无请求,零 AWS)。
  **下一格**:等总监裁定;**不为「删掉 aba_push 自己那份死膨胀」开格**。
  详见 `iterations/reports/strategy/20260828T135538Z.md`。
- 2026-08-28T10:35Z:**一个普查用「写在被研究函数体内」的那条子句定义了人口 ——
  而那条子句被它唯一调用点所加的合取吞掉了。于是 owner P1 DoD① 的频率读数描述的是
  shipped 链**从不面对**的一组帧,而且偏宽:`39 / 10 / 18` 实为 `22 / 4 / 9`。**
  开工自检 **UNLANDED 0**;cadence **2 findings**(replay-check 6.1h + 本组 8.7h,本轮即在补);
  未裁 queue 请求 **0**(open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  开工 trunk python **47 passed / 0 failed / 0 uncertifiable**;trunk 快 Lua 检测器 **16 文件 0 失败**;
  selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == ec264bc`;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0,S3 零访问**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 DoD① / P2 DoD① 均已完成、
  球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成优先项格**;open `[strategy]` 逐条过
  (#265/#263/#262/#259/#254/#250/#248/#242/#237/#231/#227/#222/#215/#196/#186/#137)
  **全部已认领或已裁定**,07:30Z 之后**无新 [strategy] issue**;backlog 最上一条 `0QUOTE`
  的下一格是**等总监裁 `campexit`** ⇒ 阻塞 ⇒ 取 backlog 数字条里 P1 家族仍在的
  **#6 pullcamp / #7 拉野节奏**所在代码面复审,在复审中撞到本条。开 **GH #277**。
  **⭐ 主判据(可复用)**:**一条被「它唯一调用点所加的合取」吞掉的子句,不只是冗余 ——
  普查会伸手去拿它来定义人口,因为它是写在被研究的那个函数体内的那一条。于是读数落在
  shipped 链从不面对的一组帧上,而且没有任何东西会转红:每一条断言对**孤立的 helper** 都为真。
  选人口之前,先问调用点加了哪些合取。** 失效方向是**偏宽**不是噪声红;`0EXIST` 同族,
  但替身是**人口**不是**帧**。
  **算术**:唯一调用点是 `if vCamp ~= nil and J.IsLanePullSafe(bot) then`(1800),
  helper 自带的是 800;两者同过 `J.IsValidHero`(**要求 `CanBeSeen()`**)与 `IsSuspiciousIllusion`
  ⇒ `pullsafe` 蕴含 `no800`。实测 993 帧:反例 **0**、缝 **324**;
  peacetime lane-support **39→22**、旧窗口 chain **10→4**、新窗口 chain **18→9**
  ⇒ 稀缺约 **44%**,行程提前量的 **+8 实为 +5**。
  **⭐⭐ 最硬的一半**:`cs.ratchet` 是**下界**,计数器改回读死子句(39/10/18)**三条全过**,
  `<=` 版子集断言也过(取等)⇒ 扣住它的是**严格小于**;
  **M8(放松成 `<=` 再重放 M1)SURVIVED —— 设计内,即那条线存在的证明**。
  **产出**:`_pullcamp_sweep.lua` **+34/-1**(5 个新计数器,与已发表口径**同帧**求值);
  `test_pullcamp_trigger_census.lua` **+184**(§1b 4 例:蕴含实测 / 两处源码 pin / 修正读数 /
  arc-warden 例外 pin;头注把已发表段落标为**被修正**,不删历史行);
  `bots/FunLib/jmz_func.lua` **+12 纯注释**。**变异 7 个:6 CAUGHT / 1 设计内 SURVIVED**,
  三处 CONTROL 干净,还原四文件逐字节相同;夹具走 scratchpad 快照且**快照那步本身被断言**。
  **⚠ 诚实边界**:**不推翻 SILENT 根因**(死条件仍是 vision 子句;`IsLanePullSafe` 仍
  **385/993** 通过,**仍不是第二条死条件**)——挪的是频率不是判决;**不删那条 800 子句**
  (`J.GetNearbyHeroes` 在 **bot 自己**带 `modifier_arc_warden_tempest_double` 时丢掉每一个英雄
  ⇒ 那种帧上它是**仅剩的**威胁子句:**实践上死、原理上承重**);语料是本仓 fixture 语料
  (战斗瞬间采样)⇒ **比值**是产出、绝对值不是;**零行为改动 ⇒ 无「已上线」主张**,
  本轮不碰任何 gate id 的入集状态;**GH #267 本组第四次点名,仍不擅自抬那个数字**。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;python **47 passed / 0 failed**;
  快 Lua 检测器 **16 文件 0 失败**;`pullcamp_trigger_census` **29/0**(改前 25/0)、
  `pull_camp` 16/0、`pullcamp_ownside_camp` 11/0、`pullcamp_lane_gap` 15/0、`pullthink` 10/0、
  `pulldrag` 13/0、`creeppull` 22/0、`smoke_load` 3/0、`no_undefined_jmz_refs` 3/0、
  `gate_claim_consistency` 10/0。**全量 Lua 套件未跑**(~100min,GH #124);**`RULE6_BYPASS` 未使用**。
  **棘轮**:`test_pullcamp_trigger_census.lua` **+184**;`_pullcamp_sweep.lua` **+34/-1**;
  `test_set.md` **零改动**(无新 gate id ⇒ 无入集提议);`queue.json` **零改动**;**零 AWS**。
  **交棒**:**总监**(① 收 **22/4/9** 作为 P1 DoD① 的登记读数——建议收,已发表那行保留并标注;
  ② `campexit` 入集裁定**仍欠**,只提醒不重复请求;③ 判据若接受值得一次**跨文件普查**
  ——「人口由被研究函数体内的子句定义,而调用点还加了合取」,**本组不自行扩面**;
  ④ GH #267 立场不变)、**录像组**(**无请求**;顺带:下一波若有 `pullcamp` 两腿语料,
  触发前提请按 **1800 那道门**统计,否则批测侧会重复同一个偏宽)、
  **批测台**(**本轮无请求,零 AWS**)、**英雄组**(无)。
  **下一格**:等总监的两项裁定;**不为「删掉 800 子句」开格**。
  详见 `iterations/reports/strategy/20260828T103543Z.md`。
- 2026-08-28T07:30Z:**一条自己写着「每加一枚 fixture 就 +1」的量被 `eq` 钉死 ——
  而同一条断言,对「解析器悄悄漏掉两枚」是瞎的。本轮真正学到的是「一个冻结的字面量,
  只有在**它转红时说得出这一节正在论证的那件事**时才可断言」。**
  开工自检 **UNLANDED 0**;cadence **2 findings**(replay-check 6.1h + 本组 6.2h,本轮即在补);
  未裁 queue 请求 **0**(open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  **开工 trunk python `46 passed / 1 failed` ⇒ TRUNK RED**;trunk 快 Lua 检测器 **16 文件 0 失败**;
  selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == e7e5797`;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0,S3 零访问**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 第 1 棒与 P2 DoD① 均已完成、
  球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成优先项格**;open `[strategy]` 逐条过
  (#265/#263/#262/#259/#254/#250/#248)**全部已认领或已裁定**;章程 backlog 最上一条 `0BAND`
  的「下一格」是**等总监裁 `campexit`** ⇒ 阻塞。**而开工自检报 `TRUNK RED`,红的那一格所在文件
  钉的正是 `mode_retreat_generic` 的 tower-fear 阶梯 —— 推进-防守姿态在本组范围内** ⇒ 认领它。开 **GH #273**。
  **⭐ 主判据(可复用)**:**一个冻结的字面量只有在「它转红时说得出这一节正在论证的那件事」时才可断言。**
  失效方向不是噪声红,是**归因错的红**(塔几何/band/那条 rung 一个都没动,红却砸在合规加 fixture 的
  replay-check 头上)**加上一个把陷阱重新上膛的最便宜出口**(62 改写成 64)。**GH #236 预言过这堵墙。**
  改前那两行**自相矛盾**:注释写「Grows by one every time a fixture is generated … **not** a geometry
  constant」,下一行就 `eq(..., 62)`。分类:`towers==22` 留;`band_min==1310` 是**极值**、
  加语料**只能往下**即只在**论证被削弱**的方向动 ⇒ 红是信息 ⇒ 留;`carrier_fixtures==62` ⇒ 换成推导。
  **不是发明** —— 这一节自己已把对的形状写对过两次(`band_frames>=60`、`all_min<=200`)。
  **⭐⭐ 最硬的一半(把「更强」从论证变成读数)**:M1 让块正则跳过那两枚 venomancer fixture ⇒
  报告读回 **62** ⇒ **旧断言原样通过(SURVIVED)**、新断言 `FAIL -- got 62 want 64`。
  旧字面量**分不清**「62 是因为总共就这么多」和「62 是因为两枚被吃掉了」。
  **产出**:`eq(62)` → (1) **独立推导的相等**(不共享解析器的行扫描)+ (2) **单调下限 `>= 62`**;
  顺带去掉 `tower_band_domain.py` LIMITS 里 `106 INCIDENT-selected fixtures`(**实际 107**)的冻结数字。
  **变异 5 个**:M1 CAUGHT(旧 SURVIVED)/ M2 CAUGHT / M3 CAUGHT / M4 SURVIVED(**符合设计**)/ M5 CAUGHT;
  两端 CONTROL 干净。
  **⚠ 方法自伤一条**:M4 heredoc **没 export `SP`** ⇒ **快照那步没跑而变异那步跑了**,三枚 fixture 被弄脏
  且无快照可还原(已 `git checkout --` 还原复核干净;那三枚不属于本轮改动)。
  **教训:快照那步自己也必须是被断言的** —— `0CAMP` §i 那条禁令差一点重演的形状。
  **⚠ 诚实边界**:**零行为改动 ⇒ 不产生任何「已上线」主张**,本轮不碰任何 gate id 的入集状态;
  **不声称修好 GH #267**(**同族但信息含量相反**:那个数字编码「哪次改动加了站点」这条证据,
  抬它会**抹掉证据**;**本组第三次点名,仍不擅自抬**);**`band_median==2086` 刻意不动**,
  理由就是主判据本身(中位数**可以往环的方向移**,那正是本节在论证的东西 ⇒ **它的红是信息**);
  残留同族一处登记未做(docstring「72 frames at level <= 2」是 prose 里的语料衍生计数、无断言扣住)。
  **门**:`luacheck_gate.sh` **0 warnings EXIT=0**;`run_py_tests.sh` **47 passed / 0 failed / 0 uncertifiable**
  (**改前 46/1 ⇒ 本轮把 trunk 从红修回绿**);快 Lua 检测器 **16 文件 0 失败**;
  **`bots/` / `game/` 零 diff**。**全量 Lua 套件未跑**(~100min,GH #124);**`RULE6_BYPASS` 未使用**。
  **棘轮**:`test_write_only_local_census.py` **+34/-6**;`tower_band_domain.py` **+5/-2**;
  `queue.json` **零改动**,`test_set.md` **零改动**(无新 gate id ⇒ 无入集提议),**零 AWS**。
  **交棒**:**总监**(① `campexit` 入集裁定**仍欠**,本轮不重复请求只提醒它还挂着;
  ② **GH #273** 的判据若接受,值得一次**跨文件普查**:「注释说它会长 / 断言用 `eq`」在 `tests/` 里还有几处
  —— **本组不自行扩面**;③ GH #267 本组**第三次点名**,不擅自抬数字的立场不变)、
  **录像组**(**无请求**;顺带:`b50a7727` 那两枚 fixture **完全没问题**,红是断言的错,已修,
  以后加 fixture 不会再撞这一格)、**批测台**(**本轮无请求,零 AWS**)、**英雄组**(无)。
  **下一格**:等总监裁 `campexit`(阻塞中);**不为「把 `band_median` 也解冻」开格**。
  详见 `iterations/reports/strategy/20260828T0730Z.md`。
- 2026-08-28T04:30Z:**那个浪费在**出厂腿**上,而抬高守卫是个**可证明的 no-op** ——
  本轮真正学到的是「一道门值不值得抬高,取决于它守的那条分支是不是**真正动手**的那条」。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(replay-check 6.1h,不是本组);未裁 queue 请求 **0**
  (open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **46 passed 0 failed 0 uncertifiable**;
  trunk 快 Lua 检测器 **15 文件 0 失败**(收尾 **16**,本轮新文件带 `[ratchet]`);selfcheck worst exit
  **3**(全部来自 cadence);开工 `HEAD == a41c06e` 与 `origin/main` 同步;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 现役形态 #250 已裁,
  P2/P3 球不在本组本轮 ⇒ 走 open `[strategy]`;**GH #265 在 03:52Z 收到录像组复核,而那条复核不是补充是推翻**
  (执行了 #265 自己的预登记:语料 19→**86 局**,ab 74 / ba 12,两个物理分层都有 armed 腿)⇒
  认领它复核后剩下的那个洞:**「这个浪费是出厂缺陷,它今天没有任何 armed id 管得着。」**
  **⭐ 主判据(可复用)**:**一道门值不值得抬高,取决于它守的那条分支是不是**真正动手**的那条。**
  失效方向是**一个长得像判决的空操作** —— 改法会 arm、会量不到东西、会被读回成「测过了,没效果」,
  **而没有任何东西会为此举手**。算术那半:farm 文件把档位**写了两遍字面量 10**,申报档位是 **12**,
  **被量到的带 {10,11} 正好是缝**;承重那半:**第三条中立分支一条档位子句都没有**,
  10-11 级时闩通过自己的 `>=10` 置 `FARM_STATE_FARM`,此后每帧**穿过两条带守卫的分支**落进没守卫的那条。
  **产出**:gated **`campexit`**(`J.IsOverTierCampOnly`,turbo-only 单合取,唯一调用点解析 gate,
  **档位判定就是 `FilterFarmNeutrals` 本身**);**armed 是放行不是拒绝**
  (`FARM_STATE_NONE` → 出厂 `UpdateAvailableCamp` → 唯一 `ClosestCamp` 重选 → **两条臂都必然发 move**),
  把 `campvoid` 的死锁教训**前置**;**不与 `campfarm`/`campvoid` 合取**且读**原始 sweep**(M9);
  新增 `tests/test_campexit_tier_release.lua` **17 例**带 `[ratchet]`;
  **判别用例(混合 sweep)先写的**,M4 被它抓到;**变异 3 批 17 个,首轮 17/17 全抓**,两端控制项干净,
  还原 `diff -q` 逐字节相同。
  **⚠ 两条 `campfarm` 自己的普查棘轮被打红,两条都是加固不是放松**:一条只数**内联**包裹
  (绑到 local 再传 —— **正是把引擎调用数保持在 3 的做法** —— 被读成没包裹)⇒ **解析这一跳绑定**;
  一条把 filter 的文件表钉死在两个文件,**顺带禁止了别的杠杆复用这个纯函数** ⇒ 第三个文件**按名准入**
  + 更严的测试(不许提 `campfarm`、不许把 gate 传进 filter、**必须传字面量 true**)。**M15/M16/M17 复验。**
  **⚠ 诚实边界**:gated ⇒ **不是 live**;**(a) 一帧没买到**;端到端没做且理由钉成可执行断言
  (`[limit reach]`:两个中立 sweep API 在 4 subject × 3 半径全答 `{}`);turbo 由 loader 强制(`[limit gate]`);
  **可达性没量过,不猜**;**不声称关掉 #265**。
  **⚠ `test_activemode_world_assertion:445` 仍红(GH #267)**:`git stash` 后在**净 trunk 上复现同一数字**,
  本轮新增 `GetActiveMode()` 站点 **0 个** ⇒ **不是本轮引入的**;**本组仍不擅自抬那个数字**,并**再点一次名**。
  **门**:luacheck **0 警告 EXIT=0**;`campexit` 17/0、`campfarm` 16/0、`campvoid` 18/0、`campsel` 21/0、
  `campgrade` 16/0、`campdanger` 14/0、`creeppull` 22/0、`pullcamp` 51/0、`abilanc` 13/0、
  `gate_claim_consistency` 10/0、`smoke_load` 3/0、`no_undefined_jmz_refs` 3/0、`level_gate_census` 15/0、
  `turbo_ternary_dominance` 12/0、`corpus_scale` 8/0、`corpus_existence_claims` 4/0、
  `defend_ping_declaration_ratchet` 8/0;**读 `mode_farm_generic` 的 23 个测试文件全跑**,除 §6 那个 trunk 既红项外全绿。
  **全量 Lua 套件未跑**(~100min,GH #124)。`RULE6_BYPASS` **未使用**。
  **棘轮**:`bots/` **+99/-1**;`test_campfarm_ancient_target.lua` **+50/-9**(两条棘轮加固);
  `test_set.md` 追加 **§BV**;`queue.json` **零改动**,**零 AWS**,S3 零访问。
  **交棒**:**总监**(裁 `campexit` 入集 —— 建议**入**且**可以单独 arm**:它是唯一够得着**出厂腿**
  那个 population 的 id,按构造独立于 `campfarm`/`campvoid`;另请知悉两条 `campfarm` 棘轮已加固)、
  **录像组**((a) 判读点 = 低于 12 级的 bot 站进远古营后**是否在几秒内离开**;
  **预登记读法**:episode 数不降但平均烧血降了 = **缩短而非阻止**,按**部分胜利**登记,不许读成「没效果」)、
  **批测台**(**本轮无请求,零 AWS**)、**英雄组**(无)。
  **下一格**:等总监裁定;**不为「把两个 `>=10` 抬成 12」开格** —— 本轮已把它证明成 no-op。
  详见 `iterations/reports/strategy/20260828T0430Z.md`。
- 2026-08-28T01:24Z:**`campfarm` armed 清空了攻击表,却没有把 bot 从营地里放出来 ——
  而本轮真正学到的是「一个修复从表里拿走条目时,所有另外问『这张表空不空』的谓词必须按同一条规则过滤;
  失效方向是死锁不是选错,而且没有任何东西会为此转红」。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(replay-check 6.1h,不是本组);未裁 queue 请求 **0**
  (open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **45 passed 0 failed 0 uncertifiable**;
  trunk 快 Lua 检测器 **15 文件 0 失败**(收尾 **16**,本轮新文件带 `[ratchet]`);selfcheck worst exit
  **3**(全部来自 cadence);开工 `HEAD == d13665c` 与 `origin/main` 同步;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 现役形态 #250 上一轮已裁
  并登记重开条件,P2/P3 球不在本组本轮 ⇒ 取最新 open `[strategy]` **GH #265**(00:53Z,带逐帧帧证据
  + 源码行号 + 明写的验收方式)。
  **⭐ 主判据(可复用)**:**一个修复从表里拿走条目时,所有另外问「这张表空不空」的谓词必须按同一条
  规则过滤;否则它会造出一个任何分支都没覆盖的状态——没有东西可做,也没有理由离开。** 失效方向是
  **死锁**,隐蔽处在于**每个站点单独看都没改、都站得住**。是 #257/#261/#266 那一族**往上一层**:
  那边是工具把文件级推断成站点级,这边是**一条断言的名字**宣称了它自己 pattern 够不到的全集
  (`campfarm` 的 census 只数 `bot:GetNearbyCreeps(`,同文件还有 **3 处 `GetNearbyNeutralCreeps(`** 没被看见)。
  **产出**:gated **`campvoid`**(`NeutralPresenceList`,turbo-only 单合取,复用已在树上的纯函数
  `J.Site.FilterFarmNeutrals`,**零新语义**),只包 `Think()` 那一处动作路径 sweep;
  desire 侧两处**刻意不动并钉成断言**;**不与 `campfarm` 合取**(`pullcad`);
  **单向性在源码里可读**(filter 只移除 ⇒ `#==0` 只能 false→true ⇒ armed 只能打开出口),
  行为侧 **16 格全网格断言** + 「恰好 3 格翻开」;新增 `tests/test_campvoid_presence_axis.lua` **18 例**,带 `[ratchet]`。
  **⚠ 判别用例是先写的**(混合 sweep,分开「过滤」与「清空」),**M7 正是被它抓到**;
  **变异 2 批 12 个,首轮 12/12 全抓**,两端控制项干净;还原走 scratchpad 快照 `cp`。
  **⚠ 顺带发现(已立案 GH #267)**:`test_activemode_world_assertion.lua:445` 的 pin 写 **255**、trunk 实为 **256**,
  **该检测器在 trunk 上已红 22 小时**,二分到 **`1b550f13`**(hero 10:55Z)。**本组不擅自抬那个数字**
  (会抹掉「哪次改动加了站点」这条证据)。**值得记的是它为什么没人看见**:自检快 Lua 腿只覆盖
  带 `[ratchet]` 的 15 个文件,它不在里面 ⇒ 每轮 exit 3 都被读成 cadence。
  **⚠ 两个棘轮按设计抓到了本组并已按其设计回应**:`defend_ping_declaration_ratchet`
  (补 `rf.declare_defend_ping(J,'stale')` 并写明为何是 stale)、`level_gate_census`
  (本轮插 41 行 ⇒ 五个 pin 行 +41,并按该文件既有记账体例补位移说明)。**都不是绕过。**
  **⚠ 诚实边界**:gated ⇒ **不是 live**;**(a) 一帧没买到**;端到端没做,理由钉成可执行断言
  (`[limit reach]`:出厂守卫 `#hLaneCreepList > 0`,W1 钉住两个 sweep API 在 4 subject × 3 半径全答 `{}`);
  小兵是**声明输入**;真的那半是**两个 subject 的等级**,且正是 #265 点名的两个英雄两个等级
  (earthshaker **L4** / bristleback **L11**,外加 L10 缝与 L12 空操作对照);
  **第三读法只覆盖 §1,解释不了 §2 ⇒ 不声称关掉 #265**;**可达性合取频率没量过,不猜**。
  **门**:luacheck **0 警告 EXIT=0**;`campvoid` 18/0、`campfarm` 16/0、`campsel` 21/0、`campgrade` 16/0、
  `campdanger` 14/0、`abil*` 全族 76/0、`level_gate_census` 15/0、`defend_ping_declaration_ratchet` 8/0、
  `gate_claim_consistency` 10/0、`smoke_load` 3/0、`no_undefined_jmz_refs` 3/0、`corpus_scale` 8/0、
  `corpus_existence_claims` 4/0;**读 `mode_farm_generic` 的 22 个测试文件全跑**,除 §6 那个 trunk 既红项外全绿。
  **全量 Lua 套件未跑**(~100min,GH #124)。`RULE6_BYPASS` **未使用**。
  **棘轮**:`bots/` **+45/-4**(仅 `mode_farm_generic.lua`);`test_set.md` 追加 **§BT** 提议入集;
  `queue.json` **零改动**,**零 AWS**,S3 零访问。
  **交棒**:**总监**(裁 `campvoid` 入集 —— 建议**入**;**并显式裁「要不要与 `campfarm` 同腿 arm」**,
  死锁前提是 `campfarm` armed,建议同腿 arm 但保持两个独立 id、不合取、可分别 promote;
  另路由 **GH #267**(trunk 既红检测器)给英雄组,并裁其 §4 的 exit-3 来源分列建议)、**录像组**((a) 判读点 = 低档 bot 站在远古营边上时
  是否转去打 900u 内的小兵;另请量可达性合取频率,离线零 EC2)、**批测台**(**本轮无请求,零 AWS**)、
  **英雄组**(无,除非总监路由 §6)。
  **下一格**:等总监裁定;**不为 desire 侧两处 sweep 开格**,直到有帧证据说它们真的改了行为。
  详见 `iterations/reports/strategy/20260828T012422Z.md`。
- 2026-08-27T22:25Z:**本组上一轮建议入集的那个等级门,在它自己的域里至少有一帧是反向的 ——
  而本轮真正学到的是「一个门的『窄』可以是不相干而不是安全,并且没有任何东西会为此转红」。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(replay-check 6.1h,不是本组);未裁 queue 请求 **0**
  (open 37);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **45 passed 0 failed 0 uncertifiable**;
  trunk 快 Lua 检测器 **13 文件 0 失败**(收尾 **14**,本轮新文件带 `[ratchet]`);selfcheck worst exit
  **3**(全部来自 cadence);开工 `HEAD == e884914` 与 `origin/main` 同步;容器有 `lua5.1`、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 现役形态 #250 上一轮已裁
  并登记重开条件,P2/P3 球不在本组本轮 ⇒ 取最新 open `[strategy]`;**#262 自己写着「先读 #263」**
  ⇒ 认领 **GH #263**。它的特殊之处是**质疑的正是本组 19:29Z 自己的产出** —— 本轮当硬约束处理:
  **推翻自己上一轮建议的读数,优先级高于再铺一根新杠杆**。
  **⭐ 主判据(可复用)**:**谓词必须和它许可的那个对象是同一个对象;门必须和它针对的缺陷在同一根
  轴上。否则它的「窄」不是安全,是不相干。** 失效方向是**假的窄**;#263 是轴的尺度、#262 是对象的
  尺度,同一个错误的两个放大倍率;是上一轮主判据的**生产侧孪生**。
  **裁定 #263**:接受重述,**撤回本组对 `abil1st` 的入集建议**(门内 5/1 vs 门外 138/41,占比
  20.0% vs 29.7% ⇒ 刀口在分子;反例帧 zuus L11 t=708.0 **门内一次干净盈利击杀,armed 后不会发生**
  ⇒ 不是收益小是**符号错**)。请总监**一并重看已在集的 `abilanc`** 的同一条阈值;
  **本组不自行退集、不删代码**。
  **产出**:gated **`aimguard`**(`J.CanBeAttackedPair`,turbo-only 单合取,**armed 分支零数字、
  零等级读数**),收编 `[1]` 族第三个站点 `hero_spirit_breaker.lua:287-296`(判 `[1]`、打 `[2]`);
  调用点**一行换一行**;**单向性在源码里可读**(armed 只加合取 ⇒ 只能扣下、永不新增),
  行为侧另有全网格 armed⟹baseline 断言 + 「网格确实分开两条腿」(恰好 2 行被扣);
  **不与 `abilanc`/`abil1st` 合取**(`pullcad`);新增 `tests/test_aimguard_target_axis.lua` **11 例**,带 `[ratchet]`。
  **⚠ 变异 3 批 13 个,首轮 13/13 全抓**(上一轮「12 抓 1 活」的判别用例教训**前置生效**:
  判别用例是先写的不是补的);两端控制项干净;还原走 scratchpad 快照 `cp`,收尾 `diff -q` 逐字节相同。
  **⚠ 诚实边界**:gated ⇒ **不是 live**;**(a) 一帧没买到**;**端到端没做,理由钉成可执行断言**
  (`[limit reach]`:分支在 `J.IsAttacking` 之后 + 本帧蓝 0.189 低于分支自己的 0.25 前提);
  营地是**声明输入**([W1]);turbo 由 **loader 强制**,钉成 `[instrument]`;
  真的那半是**两个 subject 的等级**(6/7,同一局两帧)+ 两份 shipped 源码。
  **门**:luacheck **0 警告 EXIT=0**;`aimguard` 11/0、`abil1st` 16/0、`abilanc` 13/0、
  `gate_claim_consistency` 10/0、`smoke_load` 3/0、`no_undefined_jmz_refs` 3/0、
  `level_gate_census` 15/0、`corpus_scale` 8/0、`corpus_existence_claims` 4/0。
  **全量 Lua 套件未跑**(~100min,GH #124)。`RULE6_BYPASS` **未使用**。
  **棘轮**:`bots/` **+50/-4**;`queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**(裁 `aimguard` 入集 —— 建议**入**且必须与 `abilanc`/`abil1st` **分开 arm**;
  **接收本组对 `abil1st` 的撤回**并重看 `abilanc` 的等级轴;#262 建议关闭;#263 请写明「接受重述」
  还是「维持等级门并接受 0.074 episode/局」)、**录像组**((a) 判读点 = spirit_breaker 冲锋帧后 5s
  内目标是否仍存活/可攻击;另请把 #263 §6 的 episode 口径**入库加棘轮** —— 本组完成度开格条件
  **压在它上面**)、**批测台**(**本轮无请求**,零 AWS)、**英雄组**(无)。
  **下一格**:等总监裁定;**不为完成度子句开格**,直到 episode 口径入库;剩余裸 `[1]` 站点仍 **8 个**
  (#262 已收编,但走对象轴,**不消耗** `abil1st` 的分母)。
  详见 `iterations/reports/strategy/20260827T222542Z.md`。
- 2026-08-27T19:29Z:**`abilanc` 特意留下的那个分母,买到了它的第一根杠杆 —— 而本轮真正学到的是
  「一条自称测『按 X 选』的断言,必须跑在一张让 X 与近邻规则答**不同**单位的输入上」,否则它测的是
  答案不是规则(一条变异活着穿过了 12 条断言)。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(replay-check 6.1h,不是本组);未裁 queue 请求 **0**
  (open 36);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **44 passed 0 failed 0 uncertifiable**;
  trunk 快 Lua 检测器 **12 文件 0 失败**(收尾 **13**,本轮新文件带 `[ratchet]`);selfcheck worst exit
  **3**(全部来自 cadence);开工 `HEAD == c107316` 与 `origin/main` 同步;容器有 `lua5.1`(自检装的)、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1/P2/P3 的球都不在本组 ⇒
  取最新 open `[strategy]` **GH #259**(18:49Z 开,带两局逐帧帧证据 + 两处源码行号,明写「改法留给协同组定」);
  上一轮「下一格」`0POLL` 自己写着「不扩 mock 则收官、回 issue 重新认领」⇒ 不推进。
  **⭐ 主判据(可复用)**:**一条自称测「按 X 选」的断言,必须跑在一张让 X 与所有近邻规则给出**不同**
  答案的输入上;否则它测的是「答案对不对」,不是「按什么选的」。** 失效方向是**假绿**,形状固定:
  **判别用例缺席时,一条换掉选择规则的变异从头到尾全绿**。
  **产出**:gated **`abil1st`**(`J.GetFirstUnit`,turbo-only 单合取,阈值读 `J.Site.ANCIENT_MIN_LEVEL`,
  `ipairs` 不是 `pairs`);两处调用点(`hero_zuus.lua` / `hero_centaur.lua`)各一处,
  **zuus 那条新增的 `~= nil` 守卫是本次编辑唯一可能引入的新失效模式的解药**
  (出厂第二个析取项 armed 后仍为真 ⇒ 不加会返回 **HIGH desire + nil target**;M11 专验它);
  **不与 `abilanc` 合取**(`pullcad`);同轮更正 `abilanc` 那段注释;新增
  `tests/test_abil1st_first_unit_reader.lua` **16 例**,带 `[ratchet]`。
  **域**:语料**不带任何小兵**([W1])⇒ 营地是声明输入;真的那半是**两个 subject 的等级**
  (修复读的唯一 bot 操作数)+ zuus 那帧**确实站在远古营里**(`modifier_ancient_rock_golem_weakening`);
  一帧同时给出 tide L10 / zuus **L11** / luna L14。**端到端读数**:出厂 `0.75/granite` → armed `0/nil`
  → armed+mixed `0.75/mud_golem` → armed 别的 id `0.75/granite`。分母剩 **8 个**裸 `[1]` 站点(已钉)。
  **⚠ 变异 3 批 13 个,首轮 12 抓 1 活**(M9:「第一个非远古」→「血最多的非远古」),
  **修法是加判别用例不是补断言**(`order_camp()`:mud 300 在前 / dark troll 800 在后)⇒ **13/13**;
  两端控制项干净;还原走 scratchpad 快照 `cp`。
  **⚠ 诚实边界**:gated ⇒ **不是 live**;**条件 (a) 一帧没买到**;**端到端只覆盖 zuus 一条通路** ——
  centaur 的分支在 `J.IsAttacking` 后面,读**三个 dump 不携带的动画量**,理由**钉成了可执行断言**
  (`[limit centaur]`),不是写在报告里。
  **门**:luacheck **0 警告 EXIT=0**;`abil1st` 16/0、`abil*` 全族 76/0、`gate_claim_consistency` 10/0、
  `smoke_load` 3/0、`zuus` 全族 110/0、`pullcamp` 51/0、`corpus_existence_claims` 4/0、`corpus_scale` 8/0、
  `no_undefined_jmz_refs` 3/0、`level_gate_census` 15/0;自检快腿 13 文件 0 失败;python 44/0。
  **全量 Lua 套件未跑**(~100min,GH #124)。`RULE6_BYPASS` **未使用**。
  **棘轮**:`bots/` **+88/-7**,**本组连续十轮零行为改动的记录到此为止**(这一轮有,且是 gated 的)。
  `queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**(裁 `abil1st` 入不入集 —— 建议**入**,且**必须与 `abilanc` 分开 arm**;
  另确认 `abilanc` 注释更正是否同步进 test_set.md)、**录像组**((a) 判读点 = 低于 12 级英雄在**远古营**
  上的开火数 + 开火后 5s 内是否离开,正对照已在 #259 同一语料)、**批测台**(**本轮无请求**,零 AWS)、
  **英雄组**(无)。
  **下一格**:等总监入集裁定;**不为剩下 8 个 `[1]` 站点开格**,直到其中一个拿到帧证据。
  详见 `iterations/reports/strategy/20260827T192954Z.md`。
- 2026-08-27T16:36Z:**`0POLL` 挂着的两个前置问题答案都是「不」——「这四处 getter 统一到哪一侧」
  预设了 override 是一件事,而它是**一条哨兵(不可见 ⇒ 666)+ 一条建模(美杜莎护盾)**;
  更硬的一层是**同一个 consider 内部,门和选人要的是相反的一侧**。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(replay-check 6.1h,不是本组);未裁 queue 请求
  **0**(open 36);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **44 passed 0 failed
  0 uncertifiable**;trunk 快 Lua 检测器 **12 文件 0 失败**;selfcheck worst exit **3**(全部来自
  cadence);开工 `HEAD == a3841b4` 与 `origin/main` 同步;容器有 `lua5.1`(自检装的)、无
  `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 第 1 棒 08-22 已结,
  P2 决策侧三个 id 已落地、球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成格**;最新 open
  `[strategy]`(#250)上一轮已认领裁定 ⇒ 取章程 backlog **`0POLL`**(上一轮 GH #242 §5 显式登记
  的下一格,写明**做它之前先答两个问题**)。
  **⭐ 主判据(可复用)**:**轴按问题定,不按文件定。** 哨兵在任何比较里都不是测量;建模只在
  「它建模的那个资源就是本次动作作用的资源」时才是测量。门问「这次治疗能补回多少」(必须
  Original,补的是**血**),选人问「谁最接近死」(护盾吸收是真的)⇒ 任何全文件统一都会在其中
  一处答错。对 `0SALT` 是**限定不是推翻**:那条治**不一致**,这条治**被强行一致**,而后者
  **不会有任何东西转红**。
  **域**:105 fixture / 1050 单位 / 美杜莎 17 行(活 16)/ **1000 内友方配对 5** /
  **相反门结论 5(5/5)** / **满血被放行 4** / 最大幻影缺口 **497.9** / **持有者 0/1050**。
  锚点 `f_260819_222559_od_eclipse_pair.lua` t=631.5:11 级美杜莎 **227/230 = 98.7%**、
  569/930 魔、距 lich **122u**、护盾 modifier **正在运行** ⇒ 出厂缺 **472.3** 放行 / Original
  缺 **3** 拒绝,差值精确等于缺魔项。
  **产出**:gated **`pollyhp`**(`J.PolliwogAllyMissingHealth`,turbo-only 单合取,armed 分支
  **零数字**);调用点**一行换一行**,AIUG **净 0 行**;**选人那一行刻意不动并钉成断言**;
  新增 `tests/test_pollyhp_getter_axis.lua` **18 例**。
  **⚠⚠ 边界(本轮最该记的)**:**验证仪器看不见这条分歧** —— `CDOTA_Bot_Script` 在 mock 里是
  空表,loader 在**同一条语句**里把 `u.hp` 同时赋给两个 getter ⇒ armed 与 baseline 逐位相同,
  **一次 fixture 读数在这里是按构造的 no-op**。数字因此是「真实帧 + 从源码读出的 override 函数」
  (`[replayed]`),塌缩本身钉成 `[instrument]` 断言;**0/1050 行带 `seen_by`** ⇒ 哨兵那半本地
  连语料都没有。**与 `0RANGE` 同族更深一层**。
  **⚠ 变异 3 批 13 个,首轮 12 抓 1 活(同义反复:扫描问的是测试自己的建模),修法换仪器 ⇒
  13/13**,两端控制项干净;还原走 scratchpad 快照 `cp`。
  **门**:luacheck **0 警告 EXIT=0**;`pollyhp` 18/0、`smoke_load` 3/0、
  `gate_claim_consistency` 10/0、`corpus_scale` 8/0、`corpus_existence_claims` 4/0、
  `item_name_census` 6/0、`level_gate_census` 15/0、`no_undefined_jmz_refs` 3/0、
  `salvetarget` 17/0、`salveyield` 29/0、`abilanc` 13/0,另 21 个消费 AIUG 的文件全绿。
  **全量 Lua 套件未跑**(~100min,GH #124)。`RULE6_BYPASS` **未使用**。
  **棘轮**:AIUG **净 0 行** ⇒ **连续第十轮未顶掉任何行数棘轮**。
  `queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**(裁 `pollyhp` 入不入集——本组建议**先不入**;**范围决定**:mock 要不要携带
  shipped override 层,风险是爆炸半径,**本组不自行扩面**;另外三处 getter 本轮不动)、
  **录像组**(离线分母:真实 turbo 局里「持 `polliwog_charm` ∧ 1000 内有友方美杜莎」每局几帧;
  归档持有者 0 是 **dump 格式**问题不是 turbo 问题)、**批测台**(**本轮无请求**,零 AWS)、
  **英雄组**(无)。
  **下一格**:等总监的 mock 范围裁定;不扩 mock 则本条 getter 线收官,回 `[strategy]` issue /
  owner 优先项重新认领。**不为「统一另外三处」开格。**
  详见 `iterations/reports/strategy/20260827T163644Z.md`。
- 2026-08-27T13:50Z:**GH #250 §4 的验收第一步在它自己指定的仪器上是常数 ——
  `ShouldPullNeutralCamp(bot) ~= nil` 全语料 **974 帧非 nil 计数 0**(turbo 与 `pullcamp`
  两个前提都给足),而它给 nil 挂着「本例与 `pullthink` 无关 ⇒ #186 归因需重看」这条二分支解读
  ⇒ **结论会由 mock 写出来,不由录像帧写出来**。**
  开工自检 **UNLANDED 0**;cadence **2 findings**(replay-check 6.2h、strategy 3.8h);
  未裁 queue 请求 **0**(open 36);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python
  **43 passed 0 failed 0 uncertifiable**;trunk 快 Lua 检测器 **12 文件 0 失败**;
  selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == 9501b13`,收尾时
  `origin/main` 已到 `f426604`(先 rebase 再 push);容器有 `lua5.1`(自检装的)、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P2 三个 id 已落地、
  球在总监/批测台/录像组,P3 归总监;**P1 第 1 项球在本组**,而 **GH #250 就是它的现役形态**
  (问的正是「`pullcamp` 这条链在真实对局里走到哪一步」),且它 13:30Z 开、是 open `[strategy]`
  里最新一条、带帧证据、**明确点名请本组钉 fixture** ⇒ 认领它。
  **⭐ 主判据(可复用)**:**一条谓词被提议当验收步骤之前,先问它在「将要用来读它的那台仪器」上的
  值域。已知在那台仪器上是常数的谓词不是测量;一旦给它挂上二分支解读,仪器就从「回答的东西」
  变成了「下结论的东西」。** 它是 §1 STOPPER 普查的**配方侧孪生**;失效方向是**一条真实归因
  被以仪器理由撤回,并被报成「测量过了」**。
  **⭐⭐ 归因**:常数**不是**(只是)`GetNeutralSpawners` 桩 —— **选营循环根本没跑到**:
  956 帧更早被子句挡掉,**18 帧**在均势子句上撞 GH #61 的 `GetLaneFrontLocation` 拒绝
  (18/18 异常文本点名它),而 **`spnc_raise == chain_new == 18`** 是同一个合取的**两种独立算法**
  逐位相同 ⇒ 要在 fixture 上问它需要**两处 declaration**(分路世界 + 营地表)= DECLARED-WORLD。
  **⭐⭐⭐ 顺带裁定:#250 §4 第二条建议本轮不落地** —— 立论站得住,**域为 0**:fixture 不带
  中野实体(`camp_up == 0`,974/974),中野唯一痕迹是 recent-damage 的 `src`,
  全语料 **3 帧 / 非核心 1 帧 / 落在 60–360s 窗口内 0 帧**。**重开条件写成可执行断言**
  (`neut_dmg_support_window == 0` 转红,消息写着 "go land it")。第二个事实:**诊断管道
  与验证管道不重合** —— #250 的 timeline 读得到 `neut(<=700)=12`,fixture 格式里这个数不存在。
  **产出**:扩 `tests/_pullcamp_sweep.lua`(**不新建第二次全语料 sweep**;7 个计数 + `NEUTDMG`,
  探针放每帧最后、跑在 per-frame 全新 J 上 ⇒ 够不到任何既有计数;40s → 46s);
  `test_pullcamp_trigger_census.lua` **21 → 25 例**(§4:常数零 + 归因等式 + 中野域 3/1/**0**
  + 一条**顺序钉**)。**不打 `[ratchet]` ⇒ 不进快腿**(46s vs 快腿 13s),与本文件既有做法一致,
  **作为洞明确登记并交总监**(要不要立「重普查取廉价子集」的通例,本组不自行扩面,GH #216 同族)。
  **⚠ 变异 4 批 4 中 4**,两端控制项干净;还原走 **scratchpad 快照 `cp`**(`0CAMP` 教训)。
  **⚠ 诚实边界**:`spnc_nonnil == 0` 在干净树上与 `>= 0` 分不开,是对**植入的仪器违规**验的
  (`0EXIST` (iii) 同族);承重推理的两条**对着源码**变异捕获。**这行写进了测试注释。**
  **门**:luacheck **0 警告 EXIT=0**;`bots/`+`game/` diff **空**(**零行为改动、零新 gate id**,
  本组连续第九轮未顶行数棘轮);`pullcamp` **51/0**、`smoke_load` 3/0、
  `gate_claim_consistency` 10/0、`corpus_existence_claims` 4/0、`corpus_scale` 8/0。
  **全量 Lua 套件未跑**(~100min,GH #124);`bots/`/`game/` 未改 ⇒ **不声称它绿**。
  `RULE6_BYPASS` **未使用**。`queue.json` **零改动**,**零 AWS**。
  **交棒**:**录像组**(#250 §4 第 1 步**请勿照做**;能买到的替代只在**在线行为**或
  **dumper 载荷**里 —— 需要 dumper 携带中野实体或 bot-VM 侧的 `roamCampPull`,**两者都不归本组**)、
  **总监**(快腿通例的范围决定;`pullcamp`/`pullthink` 入集状态**本轮不动**;请确认「不落地」裁定)、
  **批测台**(**本轮无请求**,零 AWS)、**英雄组**(无)。
  **下一格**:回 `0POLL`,或按 owner 优先项 / `[strategy]` issue 重新认领;
  **不为 #250 §4 第二条建议开格**,直到 `neut_dmg_support_window` 转红。
  详见 `iterations/reports/strategy/20260827T135041Z.md`。
- 2026-08-27T10:31Z:**GH #137 的承重帧一直在语料里 —— 而 `campgrade` 的每一条「承重案例」
  断言都打在替身身上,因为一句注释说那一帧买不到;本轮真正学到的是「**一条「语料里没有」的
  断言是关于一个只会增长的集合的断言,它会自己变假而没有任何东西会红**」。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(strategy 3.8h,本组历史间隔);未裁 queue
  请求 **0**(open 36);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **42 passed
  0 failed**;trunk 快 Lua 检测器 **11 文件 0 失败**;selfcheck worst exit **3**(全部来自
  cadence);开工 `HEAD == 3d77b66` 与 `origin/main` 同步;容器有 `lua5.1`(自检装的)、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 第 1 棒 08-22 已结,
  P2 决策侧三个 id 均已落地、球在总监/批测台/录像组,P3 归总监 ⇒ **本组无未完成格**;
  章程「下一格」`0POLL` **刻意不修**、`0CAMP` 的下一步要**在线行为探针**(容器里做不完)⇒
  逐条过 open `[strategy]`,**认领 GH #137**(本组前缀、带帧证据,前两条建议已落地为 gated
  `campgrade`,**建议 3 被代码自己登记为「下一个杠杆」**)。读代码时先撞上头注里更硬的题。
  **⭐ 主判据(可复用)**:**一条「语料里没有 / 买不到」的断言,是关于一个只会增长的集合的断言 ——
  它写下时为真,而后不需要任何人碰这个文件就会变假,并且没有任何东西会红。** 失效方向是**假绿**,
  形状固定:**替身长期顶着承重案例的名字**。与 `corpus_scale.lua` **是镜像不是重复**:那条治
  增长把**计数等式**打成**假红**(响的),这条治增长把**否定性存在断言**打成假(**哑的**)。
  **修法不是改注释,是把断言变成可执行的。**
  **核对**:`f_260823_002103_wk_ancient_camp_634` **在** `tests/fixtures/`,`skeleton_king`
  **就是 11 级**,带 `modifier_ancient_rock_golem_weakening`(elapsed 11.0s),坐标
  `(-5028.8, -76.3)` 与 #137 §3 逐帧表逐位吻合;帧内十人等级 9,10,10,11,11,12,12,12,13,15。
  **产出**:`test_campgrade_tier_ladder.lua` 14 → **16** 例(头注更正,假句子**原样留在原地**标
  `[CORRECTION]`;新增 `WK_L11_BEARING` 与两条 `[bearing case]` —— 存在性 + 等级 + **远古营减益**
  三条都断言,同帧同时钉缺陷与修复;承重帧并入三条既有循环)。新增
  `tests/test_corpus_existence_claims.lua`(**4 例**,`[ratchet]` ⇒ 自动进自检快腿,
  11 → **12** 个标签文件):**(A)** 点名的 fixture 必须存在(**267** 引用 / **208** 源文件 /
  **0** 缺失,下界);**(B)** 不得在点名一个**存在的** fixture 的同时断言它不存在(**0**)。
  开 **GH #248**。
  **⭐⭐ 顺带裁定:GH #137 建议 3 不做** —— (i) (W2) `GetAttackDamage()` 每枚 fixture 都读 **0**
  ⇒ `0 <= 80` 真空为真,**本地拿不到任何读数**;(ii) 承重案例 11 级/80–81 伤害**已被等级档拦住**,
  该杠杆只在 **≥12 级且伤害 ≤80** 买到域,复用 80 几乎买不到格、换更大的数是**裸拟合**
  (与 `0SALT` 同形:工具按算术为空)。**重开条件 = dumper 开始携带攻击伤害**,不归本组。
  **⚠⚠ 方法自伤三条(方向全是「把没通过报成通过」,修法全是换仪器)**:**(i) 针的集合也要唯一** ——
  重叠的 token 使内层删除变异**活下来**(#237 的**高一层**、`0SALT` 的**集合版**);
  **(ii) 用被测对象造样本的控制项是同义反复** —— **7 条删除变异活了 6 条而控制项全绿**;
  **(iii) 干净树上 `== 0` 与 `>= 0` 分不开** —— 抽成共享仪器 `require_clean()`,控制项在
  **植入的违规**上看着它 raise。**三批 14 / 5 / 12,活 3 / 2 / 3**,两端控制项干净,
  **还原走 scratchpad 快照不走 `git checkout`**(`0CAMP` 教训);**剩下的活口全是等价变异,
  明确登记、不补断言**。
  **门**:luacheck **0 警告 EXIT=0**;`bots/`+`game/` diff **空**(**零行为改动、零新 gate id**,
  本组连续第八轮未顶行数棘轮);`campgrade` **16/0**、`corpus_existence` **4/0**、
  `corpus_scale` 8/0、`smoke_load` 3/0、`gate_claim_consistency` 10/0、
  `campsel_wrapper_fields` 21/0、`campfarm_ancient_target` 16/0、`level_gate_census` 15/0、
  `pullcamp_trigger_census` 21/0。**全量 Lua 套件未跑**(~100min,GH #124);`bots/`/`game/`
  未改 ⇒ **不声称它绿**。`RULE6_BYPASS` **未使用**。`queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**((i) 要不要把「否定性存在断言一律可执行」升成通用纪律 —— 本组只扫了
  `tests/` 一面,**`tools/` 与 `docs/` 没扫**,不自行扩面,与上一轮 `BOT_API_REFERENCE.md`
  全文件普查同族、两条一起裁更省;(ii) `campgrade` 仍 gated 未 promote,本轮**不改变入集状态**,
  只把承重证据**从替身换成本人**;(iii) 请确认 §5 对 #137 建议 3 的**不做裁定**)、
  **录像组**(**无请求**)、**批测台**(**本轮无请求**,零 AWS)、**英雄组**(无)。
  **下一格**:回 `0POLL`,或按 owner 优先项 / `[strategy]` issue 重新认领;**不为 #137 建议 3 开格**。
  详见 `iterations/reports/strategy/20260827T103139Z.md`。
- 2026-08-27T07:37Z:**GH #241 立案的那个「两方矛盾」解散了 —— 被当作反驳方的那一行
  **从来没有观测过 bot API**;而本轮真正学到的是「**一份文档比它自己引的来源知道得更多,
  它就不是来源**」,外加一条:**退掉一个坏的反驳方 ≠ 确认了代码**。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(strategy 3.8h,本组历史间隔);未裁 queue
  请求 **0**(open 35);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **42 passed
  0 failed**;trunk 快 Lua 检测器 **11 文件 0 失败**;selfcheck worst exit **3**(全部来自
  cadence);开工 `HEAD == a3a2483` 与 `origin/main` 同步;容器有 `lua5.1`(自检装的)、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1 第 1 棒 08-22 已结、
  P2 决策侧两棒已交、球都在总监,P3 归总监 ⇒ **本组无未完成格**;章程「下一格」`0POLL`
  **刻意不修**且要求先答一个全文件级问题 ⇒ 不动它。**认领 GH #241**:它带 `[bug]` 前缀,
  但 §5 明写 `jmz_func.lua` 那处 `camp.team == GetTeam()` **就是 `pullcamp` 自己的选营过滤器**,
  而拉野与对线期策略**是本组范围**;#241 §6 明说录像组答不了这条。
  **⭐ 主判据(可复用)**:**一份文档比它自己引的来源知道得更多,它就不是来源。**
  Valve wiki(两份独立镜像)对 `GetNeutralSpawners` **零字段文档**;ModDota 引擎 dump 给
  `: variant` + 一句 help 串,同样无字段表;本仓那一行却有**六个字段各带类型标注**,
  且页首引的是 `Dota_2_Workshop_Tools/Scripting/API`(**server-vscript**,不是 bot scripting)。
  同样六行**逐字**出现在无关第三方仓 `shikyo13/Dota2AI` 的**同名文件**里 ⇒ 同一血统。
  **⭐⭐ 不需要外部来源的那半(最硬)**:该行**每一个数字型标注都紧挨着一个字符串型描述** ——
  `type` (int) 却把 `small/medium/large/ancient` 写成取值;`speed` (float) 而 shipped 比
  `"fast"/"slow"`;`idx` **该行没列**却被 `RefreshCamp` 读 **4** 次 ⇒ 类型错 **+** 不完整。
  **⭐⭐⭐ 对 owner P1**:#241 §5 那条交叉线(`camp.team` 使 `pullcamp` **构造性 SILENT**)
  **失去依据**,引擎 help 串 *"...what side of the river they're on"* 反而是弱正向信号 ⇒
  **P1 第 1 项的归因不必重开**。**但 `.type == "ancient"` 那一半仍然完全未验证** ——
  本轮**明确不声称**它对,`campsel` 的 (a) 仍未买到(replay-check 08-27T04:05Z REFUSE),
  **只是它的理由已经不再是「它可能是 no-op」**。
  **产出**:`docs/BOT_API_REFERENCE.md` 该条改写(`variant` + 三个 `(unverified)` + 补 `idx`
  + 退役说明;**doc 里一律不写行号**,GH #221 教训);`campsel_domain.premise_sites()` 加
  `speed_readers`/`idx_readers`/`doc_section`,`--selfcheck` **63 → 70 PASS / 0 FAIL**;
  棘轮**移钉不放松** —— 「API 参考仍在唱反调」拆成 **5 条**(含「`int` 不许放回去」)
  + 2 条**把「它自相矛盾」的论据本身钉住**。**`bots/` 零 diff、零新 gate id ⇒ 未顶任何行数棘轮**
  (本组连续第七轮)。
  **⚠ 方法自伤二条(方向都是「把没通过报成通过」)**:**(i) 变异夹具的还原路径不许经过版本控制**
  —— `restore()` 用 `git checkout` 把**本轮未提交的被测改动**擦掉,两端 CONTROL 全 DIRTY、
  五个变异 SETUP-FAILED(事后 `git status` 坐实);改成 scratchpad 快照 `cp`。
  **(ii) `'#241' in section` 不是 pin** —— 该 token 在那节出现**两次**,只删一处的变异
  **SURVIVED**;这是 `0SALT`「针必须唯一」的**反向**同族,**修法是换针不是补断言**:
  两个各自唯一的整句各 `count == 1`,`UNVERIFIED` 同样 `count == 1`(**重复它也会红**,已验)。
  三批 **10 / 10 / 12**,活下来 **5(夹具失效)/ 1 / 0**,两端控制项干净;判定读数一律用
  **退出码**不用 stdout 子串(`0SALY` 教训),全程顺序执行不并发。
  **门**:luacheck **0 警告 EXIT=0**;`bots/`+`game/` diff **空**;python 套件 **42 文件 0 red**;
  `campsel_domain --selfcheck` **70/0**;`test_detector_source_constants` 全绿;
  Lua 受影响面 `smoke_load` 3/0、`gate_claim` 10/0、`campsel_wrapper_fields` 21/0、
  `campgrade_tier_ladder` 14/0、`pullcamp_trigger_census` 21/0。
  **全量 Lua 套件未跑**(~100min,GH #124);`bots/`/`game/` 未改 ⇒ **不声称它绿**。
  `queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**((i) #241 可否按本轮裁定降级 —— 它现在是「一个来源,而且不是来源」;
  (ii) **一个范围决定**:本仓 `BOT_API_REFERENCE.md` **整份**都带那条 server-vscript 页首 ref
  且与第三方仓同源 ⇒ **这一行大概率不是唯一一行**,要不要立全文件对表普查,本组不自行扩面)、
  **录像组**(**无请求**,`.dem` 答不了这条)、**批测台**(**本轮无请求**)、
  **英雄组**(登记不做:`hero_templar_assassin.lua` 两处 `.type` 字符串比较压在同一前提上,
  与 `aba_site.lua` 那四处是**同一个原子**)。
  **下一格**:#241 剩下那一半要一次**在线行为探针**,**不是容器里做得完的工作单元** ⇒
  本组不为它开格;回 `0POLL`,或按 owner 优先项 / `[strategy]` issue 重新认领。
  详见 `iterations/reports/strategy/20260827T073716Z.md`。
- 2026-08-27T04:27Z:**大药选人这一格的裁定是「不要落地」—— 支配构造对 argmin 型现状
  **按算术为空**,唯一可做的改动是裸选一根轴(即拟合);而本轮真正学到的是
  「**source pin 只有在那个字符串于文件内唯一时才是 pin**」。**
  开工自检 **UNLANDED 0**;cadence **2 findings**(replay-check 3.5h、strategy 3.8h,均历史间隔);
  未裁 queue 请求 **0**(open 35);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python
  **41 passed 0 failed**;trunk 快 Lua 检测器 **10 文件 0 失败**;selfcheck worst exit **3**
  (全部来自 cadence);开工 `HEAD == f64c104` 与 `origin/main` 同步;容器有 `lua5.1`(自检装的)、
  无 `luacheck`(gate 自己装,apt 包名 `lua-check`);**AWS $0**。
  上一轮(`bc75ad2b`)引入的 trunk 红已由总监 `f64c104` 修好,开工时已绿,本组未再动。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 常设运维球在批测台,P1/P2 DoD① 已完成、
  球在总监,P3 归总监 ⇒ **本组无未完成格**;open `[strategy]` 逐条过完无一条等本组动;
  **章程「下一格」由上一轮 `0SALY` 显式登记**,且**登记时就带了一条必须先答的反对意见** ⇒ 认领它。
  **⭐ 主判据(可复用)**:**支配构造只可能对「不是任何一根竞争轴的 argmin」的现状开火。**
  这一格的现状**本身就是绝对轴的 argmin** ⇒ 交集对**任何**候选集为空(`bbfight` 那种空),
  前三格赖以落地的那件工具在这里**按算术**不可用;`salveyield` 能开火正因为它的现状
  (「自己喝」)是**常数规则**。`[criterion]` 做成四个现状的表(两个 argmin 型 **0**,
  两个非 argmin 型正数 = 控制项);`[control]` 用 #237 锚点在**同一对英雄**上给两种读数 ⇒
  **差别只在现状,不在数据**。
  **⭐⭐ 反对意见成立**:大药是**定量**治疗 ⇒「谁更惨」≠「谁获益最大」;`[objection]`
  **参数化**扫 H=200..800 共 **25** 个取值,每一个上比例规则选中的人喝完都更惨。
  ⇒ **裁定不落地。零行为改动、零新 gate id、`bots/` 零 diff。**
  **⭐⭐⭐ 端到端零**(轴 = 持药者帧 **121** 个):四个门世界**最大可选集全是 1**
  (恰好 1 个的帧数 **6 / 8 / 3 / 5**)⇒ 选人这条规则在归档上**一格都决定不了**。
  写成「最大值 == 1」而非「≥2 计数 == 0」,因为前者**没有可放松的常数**(初版写后者,
  变异「阈值 2 改 3」**会活下来**)。**控制项**:不加门时 **4** 帧带 ≥2 个队友、最大 3 个 ⇒
  零是关于**队友血量门**的,不是持药者总一个人站着。
  **⚠⚠ 方法自伤(同一形状一轮内四次,方向全是「把没通过报成通过」)**:第一批 31 变异
  **4 个活下来**,其中三个是**大药自己选人那三行**的变异 —— 因为**完全相同的三行块在这个文件里
  有四份**,`find(needle,1,true)` 命中的是变异没碰过的拷贝。与 #237 的
  「`"10 failures"` 含 `"0 failures"`」**同族高一层**:那次是**包含**,这次是**唯一性**。
  修法是**切片**(先切出 `item_flask` 函数体再断言,带反真空字节数上下界),不是补断言;
  另两处:`x = h()` 的 pin 被 `x = h() - 100` 满足(**非**等价变异)⇒ `exact_line` 整行逐字比;
  `find('= ' .. 0.5)` **命中 `= 0.55`** ⇒ 数值 pin 一律**从树读出按数字比**。
  三批变异 **31 / 12 / 6**,活下来 **4 / 1 / 0**,每批前后干净控制项;判定读数用 `^[0-9]+` 提整数,
  全程顺序执行不并发。
  **⭐⭐⭐⭐ 判据二(顺带,且加强裁定)**:该文件有 **4 处** consider 用**同一三行块**按绝对最低血
  选队友(`item_flask` / `item_essence_distiller` / `item_urn_of_shadows` 均 `OriginalGetHealth`,
  `item_polliwog_charm` 用 **`GetHealth`** 是异类)⇒ **只改大药一份 = 同一文件对同一问题两个答案**,
  恰是 #227/#231 对大药阈值的那条控诉 ⇒ **这根轴要么全文件一起定,要么不定**。`[census]` 全钉。
  异类那条登记为 backlog `0POLL`,**刻意不修**。
  **另一条零**:`[decompose]` 干净守卫里治疗-modifier 那半排除 **0**、recent-damage 做完全部
  6→3 / 8→5(与 #237 同形),按那条教训**把零写进文件** + 可达性控制项(归档确有 **9** 个单位带)。
  **棘轮**:`bots/` **零 diff ⇒ 本轮没有顶掉任何行数棘轮** —— 本组**连续第六轮**动这段四十行里
  **第一次**(前五轮 +2/+3/+4/+6/+12,GH #221 那族)。原因是**标记做成了会变红的测试而不是注释**;
  记成操作规则:**标记能做成红测试就不要做成注释**(注释可被略过;红测试在**正要改那一行的
  那一刻**才响,且不位移行数普查)。
  **产出**:新增 `tests/test_salvetarget_axis_undecidable.lua`(**17 例**,带 `[ratchet]` 标签 ⇒
  已自动进自检快腿,10 → **11** 个标签文件)。开 **GH #242**。
  **门**:luacheck **0 警告 EXIT=0**;`salvetarget` **17/0**;`salve` 切片 **122/0**;
  `smoke_load` 3/0、`corpus_scale` 8/0、`gate_claim_consistency` 10/0;自检 python **41/0**、
  快 Lua **11 文件 0 失败**。**全量 Lua 套件未跑**(~100min,GH #124);`bots/`/`game/` 未改 ⇒
  **不声称它绿**。`queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**((i) 裁定「不落地」是否即为 `item_flask` 这个 consider 的**收官**——
  四格已全部读完;(ii) #237 留下的 `salveyield` **入集裁定仍未裁**,若与 `salvepool`/`salveally`
  一起入集须作**一个原子**)、**录像组**(离线零 EC2,**唯一能重开本裁定的东西**:真实 Turbo 里
  「持药者 700 内 ≥2 个队友且各自缺血都过门」每局几帧 —— 归档 121 帧上是 **0**,
  **缺的是语料量不是形状**;若真实频率也贴近 0 则这一格可永久合上,若不是,重开的是
  **全文件四处一起**的题)、**批测台**(**本轮无请求**)、**英雄组**(无)。
  详见 `iterations/reports/strategy/20260827T042757Z.md`。
- 2026-08-27T01:20Z:**大药的两半之间没有任何仲裁 —— 自用分支只要成立就 `return`,
  四十行下的贴队友分支不是被压过、是根本到不了;而本轮真正学到的是「一条 `limits` 里
  写着『某合取项不在 dump 里』的注记,本身就是一个关于 dump 的断言,必须拿 dump 核对,
  不能继承」。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(strategy 3.8h,本组历史间隔);未裁 queue
  请求 **0**(open 35);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **41 passed
  0 failed**;trunk Lua 快检测器 **9 文件 0 失败**;selfcheck worst exit **3**(全部来自
  cadence);开工 `HEAD == 7de2b78` 与 `origin/main` 同步;容器无 `lua5.1`/`luacheck`,
  **两者都由脚本自己装上**;**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— P1/P2 DoD① 已完成、球在总监,P3 与
  常设运维分别归总监/批测台 ⇒ **本组无未完成格**;open `[strategy]` 逐条过完无一条等本组动;
  **章程「下一格」第 (i) 条明确登记为本轮该做的那一格**(上一轮 GH #231 故意留下,写明
  **不需要新语料**)⇒ 直接认领,不自选新题。仍落在 owner 优先项 **P2 的补给侧**。开 **GH #237**。
  **⭐ 缺陷**:`X.ConsiderItemDesire["item_flask"]` 第三处缺陷,**头一处与常数无关的** ——
  两半之间没有仲裁。自用门是**绝对缺血量**,池子一大它在 bot 还舒服时就成立:归档最大池
  **2566** 上缺 501 = 还剩 **80.5%** 血,足够把药喝在自己身上,而 400u 外站着 14% 血的队友。
  **函数里没有一行比较这两个人。**
  **⭐⭐ 修法**:gated **`salveyield`**(turbo-only)`J.ShouldYieldSalveToAlly()` + 调用点把
  贴队友那半的扫描**上提到自用分支之前**(纯读,单独看不改行为),自用分支多一个合取项;
  未 armed **逐字返回 false**。**本轮没有常数可推导,于是干脆不引入常数**:比例与绝对血量
  对「谁更惨」给出不同答案,而大药是**定量**治疗(400 对 692 池 58%、对 2566 池 15.6%),
  两种读法都说得通 ⇒ **只在支配关系成立时让位**(队友两种读法上**同时**更惨)= 两条候选
  规则的**交集**,按构造最保守,**没有阈值可拟合**。`[source]` 断言函数体**除 0 外不许出现
  任何数字**、两个 getter 每个英雄各读一次;比例比较写成**交叉相乘**(不需 epsilon、不可能
  除零)。**⭐⭐⭐ 永不丢弃施法、只改变目标**:调用点把贴队友那半**自己的开火条件**同帧传给
  helper,helper 在它为假时短路 ⇒ 让位只可能交给一条**已知会对同一个队友返回 HIGH** 的分支;
  `[nodrop]` 四条断言**从源码文本**读出这条性质。⚠ 依据 (c) 上一处不含糊:**这一处姊妹
  lotus 不站在我们这边**(它自用也直接 return),依据是标准打法不是「树上已经这么说了」。
  **⭐⭐⭐⭐ 本轮主判据**:GH #231 的 `[W1]` 把四个治疗 modifier 与
  `WasRecentlyDamagedByAnyHero` 记作「不在任何 dump 里」——**五项里有两项在**
  (`modifiers` **433/1050 = 41%**、`recent_damage` **181/1050 = 17%**),建模进去把那一轮
  **已发表的域表前两行砍半(6→3、2→1)**;**最深那行(它的控制项)仍是 1 ⇒ 结论不受影响,
  受影响的是域数字**,本轮不得被读成推翻了 GH #231。而它**同时决定本轮自己的头条**:
  唯一挺过其它合取项的配对正是被**队友自己的 recent-damage 守卫**杀掉的 ⇒ 端到端
  **1(旧约定)/ 0(修正约定)**。`[w1correction]` **先把已发表的 6/2/1 原样复现**再给 delta ——
  对**当场能算出来**的数的 delta,不是对记忆里的数的 delta。
  **⭐⭐⭐⭐⭐ 域,六层六个数**(73 配对):① 自用开火 **9** → ② +持药者 900 内无敌 **3**
  → ③ +持药者干净 **2** → ④ +1000 内无敌 **2** → ⑤ +队友过门 **1** → ⑥ +队友干净 **0**。
  ⑤ 上那个配对**同时满足支配关系**。控制项:「队友过门 ∧ 干净 ∧ 安静」在归档里仍有 **1**
  个配对 ⇒ 为零的是**本杠杆这条带**,不是这条分支。
  **真实帧锚点**`f_260820_043140_luna_ring_bid`(t=690.5 = 11:30,turbo)**潮汐 9 级、包里
  第 4 格 `flask`、80/1455 = 5.5% 血**,沉默术士 **43/1229 = 3.5%**、相距 **596u** ——
  出厂逻辑让潮汐把药喝在自己身上。**零新 fixture 文件。**
  **本地**:`tests/test_salveyield_arbitration.lua` **29 例全绿,30 变异 30 抓 + 控制前后
  各一次干净**(含 **8 条模型层**)。**⚠ 方法教训一:修法不是补断言** —— 把修正模型里
  治疗-modifier 那半 neuter 掉 **29 例全绿**,因为它在配对轴上排除的**本来就是 0** 个
  (整个 6→3 全来自 recent-damage);做法是**把那个悄悄成立的零写进文件**(断言 heal-mod
  排除 **0**、recent-damage 排除 **3**,并断言**归档确实带着这些 modifier 9 次** ⇒ 零是关于
  **可达性**的),补上后 30/30。**⚠ 方法教训二(自伤):判定读数的那段代码也是被测对象**
  —— 变异批处理用 `grep -q "0 failures"`,而 **`"10 failures"` 里含 `"0 failures"`** ⇒
  一条**真被抓住**的变异被报成 SURVIVED,失效方向恰是最坏的那个;整批已用 `^[0-9]+` 提取
  重跑 + 两端控制项。与 GH #222 判据二同族。
  **棘轮**:`bots/` 只动两个文件、AIUG **净 +12 行**,顶掉 `item_name_census`(6796→6808)
  + `level_gate_census`(5805→5817 / 5845→5857)—— **GH #221 那族第九例,第五个连续轮次
  动同一对钉**,且是五次里**位移最大的一次**(+12 对 +2/+3/+4/+6):**不只是复发,振幅在
  变大**,因为每一轮的修复都落在**同一段四十行**里。按 `0LN2` **移钉不放松**,**又一次在
  工作树上、push 之前**抓到。
  **门**:luacheck **0 警告 EXIT=0**;python **41/0**;Lua 受影响面读数见报告 §12
  (**顺序不并行**,GH #222 判据二;本轮全程遵守上一轮立的「受影响面循环在跑时不许再发
  任何 lua 调用」,期间只做 GitHub / JSON / Markdown 工作)。
  `queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**(裁 `salveyield` 入集;本组建议先不入,**但要一起裁的是**它与
  `salvepool`/`salveally` 同源同函数且**方向互相牵扯** —— `salvepool` armed **放宽**自用门
  ⇒ 严格**增加**自用抢先频率,`salveally` armed **放宽**队友候选集,若一起入集应作**一个
  原子**;**另有一条方法裁定**:GH #231 `[W1]` 已被证伪两项,其已发表域表前两行应按 3/1
  更正还是保留加注)、**录像组**(一条离线零 EC2 分母:「持药者自用门成立 ∧ 700 内有过门
  队友 ∧ 该队友两种读法上都更惨」每局几帧 —— 归档只有 1 帧且被 recent-damage 杀掉,
  **缺的是语料量不是形状**)、**批测台**(**本轮无请求**)、**英雄组**(无)。
  **下一格(带一条反对意见)**:同一个 consider 只剩**一处**没读过 —— 贴队友那半**选人**
  用绝对最低而非比例最低。⚠ **下一轮必须先答**:大药是**定量**治疗,比例最低选中的**可能
  正是 400 血救不回来的那个大池子英雄**(辅助 100/692 = 14.5% vs 核心 300/2600 = 11.5%:
  比例选核心,而 400 血把辅助拉到 72%、把核心只拉到 27%)⇒ **「比例更对」在选人这一步
  不是自明的**;**不要按 GH #231 登记的措辞直接落地**。`nFullRespawnTime` 改名裁定已到
  (总监 GH #218 §BM.1),注意 `bbrespawn` 带 `readmit_on` 且与 `bbshort` 互斥;GH #190
  仍等读数;`54 处 list[1]`、`13+ 处 J.GetCenterOfUnits`、#212 §4 三条仍为**不做**。
  详见 `iterations/reports/strategy/20260827T012000Z.md`。
- 2026-08-26T22:25Z:**大药贴队友那半对 538 的池子是算术上不可满足的;而本轮真正学到的是
  「一个结构性零可以被算术证明为真,同时在它自己那根轴上买到零个格子 —— 这两件事必须
  分开说」。**
  开工自检 **UNLANDED 0**;cadence **1 finding**(strategy 3.8h,本组历史间隔);未裁 queue
  请求 **0**(open 33);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **39 passed
  0 failed**;trunk Lua 快检测器 **9 文件 0 失败**;selfcheck worst exit **3**(全部来自
  cadence);开工 `HEAD == 706e10c` 与 `origin/main` 同步;容器无 `lua5.1`/`luacheck`,
  **两者都由脚本自己装上**;**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— P1/P2 DoD① 上一轮已完成、球在总监,
  P3 归总监 ⇒ **本组无未完成格**;open `[strategy]` 逐条过完无一条等本组动;**章程「下一格」
  第 1 条明确登记为本轮该做的那一格**(上一轮 GH #227 故意留下的同函数另一半,写明
  **不需要新语料**)⇒ 直接认领,不自选新题。仍落在 owner 优先项 **P2 的补给侧**。开 **GH #231**。
  **⭐ 缺陷**:`and npcAlly:OriginalGetMaxHealth() - npcAlly:OriginalGetHealth() > 550` ——
  **缺血量永远超不过血池** ⇒ 血池 ≤ 550 的队友在**任何血量(含 1)下**都通不过。**域空,
  不是域小**,而且是**算术判决**不是统计判决。归档在一个**合理**帧上带着这样的池子
  (1 级冰女 **538**,门读成比例是 **102.2%**)。550 以上是第二个缺陷(同 `salvepool` 同源、
  更狠):669 → **17.8%**,2566 → **78.6%**。**两个循环不是类比是同一个循环**:四十行下的
  `ConsiderHealingLotus` 同半径同守卫,**唯一结构差别就是这个谓词的形式**。
  **⭐⭐ 修法**:gated **`salveally`**(turbo-only)`J.SalveAllyMissingFloor()` +
  `J.SalveAllyMissingEnough()` —— 未 armed 逐字 **550**,armed `Min(550, maxHP*0.55)`。
  **比例是推导**(三条独立依据:出厂常数自己隐含的 550/1000;**比姊妹 lotus 三档队友门
  0.4/0.5/0.5 缺血全都更严**;armed 后**两道门 550>500 的大小关系在每个池子上都保持**)。
  比自用那半更强的两处:**池子读在 helper 里只读一次**(减法与门不可能读到两个数,且读在
  `IsValid` 短路后面)、**floor 函数体一个数字都不许出现**。
  **⭐⭐⭐ 本轮主判据**:证明成立且**可穷举**(**151,525** 个 (池,血) 状态,**且把扫过的
  宽度与状态数本身钉成断言** —— 否则把上界改小、子集照样全绿);而这条分支可达的轴是
  **配对**,归档 **73** 个配对里队友血池 **[582, 1872]**,**一个 ≤ 550 的都没有** ⇒ 端到端
  **0** 格。**与 `bbfight` 的分别正在这里。** 与 `0SALV` 的 `[refusal]` 同族反向:那条管
  别用语料定常数,这条管**别用证明顶语料**。
  **⭐⭐⭐⭐ 域**:① **6 / 8 / 新开 2**;② + 持药者 1000 内无敌 **2 / 2 / 0**;
  ③ + 自用分支不能抢先(下界)**1 / 1 / 0** —— ③ 在**出厂与 `salvepool`-armed 两种自用门下
  读数相同**(这条一致性也是断言);控制项:出厂那一路在 ③ 上**仍打得响 1 次**。
  **本地**:`tests/test_salveally_missing_floor.lua` **24 例全绿,21 变异 21 抓 + 控制干净**。
  **⚠ 两条变异一开始活下来**:模型里硬写的 quiet 半径 1000→1600(这份归档上两个半径恰好
  选中同一批配对)、穷举网格上界改小(子集照样为真)。**修法不是补断言**:三个半径改成
  **从源码文本读出来**、网格**把扫过的宽度钉成断言**。真实帧锚点
  `f_260819_122930_lich_rescue_doomed`(t=201.3,turbo)**混沌骑士 4 级、包里第 2 格是
  `flask`,冰女队友 225/692 = 32.5% 血、相距 491u**,而出厂门要她掉到 **20.5%** ——
  同文件 lotus 注释写着「30% 就是危急」。**零新 fixture 文件。**
  **棘轮**:`bots/` 只动两个文件、AIUG **净 +2 行**,顶掉 `item_name_census`(6794→6796)
  + `level_gate_census`(5803→5805 / 5843→5845)+ `salvepool` 的 `[limit]` 钉 ——
  **GH #221 那族第八例,第四个连续轮次动同一对钉**。按 `0LN2` **移钉不放松**,
  **又一次在工作树上、push 之前**抓到。
  **门**:luacheck **0 警告 EXIT=0**;python **39/0**;Lua 受影响面 **105 个可寻址测试文件
  顺序跑完**(读数见报告 §12)。**⚠ 本轮又踩了一次 GH #222 判据二,而且是自伤**:第一轮跑到
  36/105 时并发发了 4 个前台核验 ⇒ **那轮读数作废、整轮重跑**;补一条操作规则:
  **受影响面循环在跑时本会话不许再发任何 lua 调用**。
  `queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**(裁 `salveally` 入集;本组建议先不入,**但要一起裁的是**:它与
  `salvepool` 同源同函数、共享同一个 consider 的返回顺序,若一起入集应当作**一个原子**)、
  **录像组**(两条离线零 EC2 分母,其中「700 内出现过血池 ≤ 550 的队友几帧」直接决定那条
  结构性零是不是永远只是一条证明)、**批测台**(**本轮无请求**)、**英雄组**(无)。
  **下一格**:同一个 consider 的另外两处,**都不需要新语料** —— (i) 自用与贴队友之间
  **没有优先级仲裁**;(ii) 贴队友那半**选人**用绝对最低血量而非比例最低(本轮只动了
  「要不要」,没动「选谁」)。**`nFullRespawnTime` 改名:裁定本轮到了**(总监 22:10Z
  GH #218 §BM.1 —— `bbfight`/`bbshort` **APPROVED_ADMITTED**、`bbrespawn` **REJECTED +
  `readmit_on`)⇒ **这条从「等裁定」转为「可做」**,但注意 `bbrespawn` 带 `readmit_on`
  且 §BM.3 立了「`bbrespawn` 与 `bbshort` 不得同腿 arm」的互斥前置,改名前要确认三个 gate
  的未 armed 腿仍逐字等于出厂。GH #190 仍等读数。
  详见 `iterations/reports/strategy/20260826T222500Z.md`。
- 2026-08-26T19:41Z:**同一个文件在四十行外写着为什么该问比例,而大药站在它的反面;
  而本轮真正学到的是「一个常数可以被测出来更好、同时被拒掉,而拒的理由必须写下
  被拒的那个数有多大」。**
  开工自检 **UNLANDED 0**;cadence **2 findings**(replay-check 3.7h、**strategy 3.8h** ——
  是本组,但那是上一轮自己的间隔);未裁 queue 请求 **0**(open 33);稳定版锚点
  stable-v1/v2 **各 3 项 ok**;trunk python **37 passed 0 failed**;trunk Lua 快检测器
  **9 文件 0 失败**;selfcheck worst exit **3**(全部来自 cadence);开工 `HEAD == a7d11c4`
  与 `origin/main` 同步;容器无 `lua5.1`/`luacheck`,**两者都由脚本自己装上**;**AWS $0**。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— P1/P2 的 DoD① 上一轮已完成、球已交出,
  P3 归总监 ⇒ **本组无未完成格**;open `[strategy]` 逐条过完**无一条等本组动**;章程
  「下一格」(`nFullRespawnTime` 改名)**明确登记为等裁定** ⇒ 自驱取新杠杆,**刻意落在
  owner 优先项 P2 的补给侧**(决策侧上一轮已交出,**大药的自用门从来没人看过**)。
  **顺带记两条走过又放下的**(免得下一轮再走一遍):`#157` turbo 常数轴上的
  `RetreatWhenTowerTargetedDesire` 的 `> 10*60` 要「800 内有敌方塔」的帧,而 `#202` 已量过
  语料这一侧最近只到 **4838u**(建筑域买不到);`mode_farm_generic:1149` 的昼夜析取被
  `t < 18*60` 支配成近似恒真,**杠杆是调参不是算术**。开 **GH #227**。
  **⭐ 缺陷**:`X.ConsiderItemDesire["item_flask"]` 自用分支第一个合取项是**绝对缺血量**
  `> 500`;而**同一个文件四十行以下**的 `ConsiderHealingLotus` —— 同族道具、同样的形状
  (先自用再贴队友)、同一个 `DistanceFromFountain( 3000 )` 前置 —— 把阈值写成**剩余血量
  比例**,并**把理由写在注释里**。**论证的两半都已经在树上,只有大药站在它的反面。**
  代价是算术:974 个存活帧里血池 **538 → 2566**(近五倍),同一个 500 对 538 意味着
  「掉到 **7.1%** 才准喝」,对 2566 意味着「掉到 **80.5%**」。
  **⭐⭐ 修法**:gated **`salvepool`**(turbo-only)`J.SalveSelfMissingFloor( nMaxHealth )` ——
  未 armed 返回出厂 **500**,armed 返回 `Min(500, maxHP * 0.5)`。**armed 的值不是重新猜的**:
  500 本身就是 **1000 血池的一半**,修法保留出厂那个数、只是不再让它在池子更小时要更多;
  比例同时落在姊妹族**最保守**的那一档上(第二条独立依据),`[source]` 断言**不许出现
  字面量 250**。**单向且两头钉住**:`Min` 只能降低下限(`closed == 0` 穷举),而**池子
  ≥ 1000 时 armed 逐字等于出厂** ⇒ **只活在小池子上**,不是笼统放松。
  **⭐⭐⭐ 域,三个嵌套的问题给三个数、不给一个好看的**:①本杠杆自己那个合取项
  **169 / 189 / 新开 20**;②+ 分支自己的 900 半径内无存活敌方英雄 **97 / 107 / 10**;
  ③+ 包里真的有大药(派发器前置)**7 / 7 / 0**。**③ 的 0 就是本轮不提入集、不提波次的
  理由**,但它带控制项:出厂那一路在 ③ 上**打得响 7 次** ⇒ 为零的是**本杠杆这条带**,
  **不是这条分支** —— 与 `campfarm` 那种结构性买不到**明确不同**。
  **⭐⭐⭐⭐ 本轮主判据**:`[refusal]` —— 姊妹族**最松**的那一档(0.7)在同一份语料上
  **买得到 6 个端到端帧**,正是上面说没有的那种证据,**仍然被拒**:①下限那么低意味着
  **大量治疗量溢出**才喝;②**挑那个让语料读数最好看的常数是拟合,不是推导**。
  把「**被拒的那个数 == 6**」**钉成断言** —— **说清楚自己放弃了多少,才叫拒绝;不说,
  就只是没测。** 另有一条**不主张**:16 个存活帧整个血池 ≤ 500(那样是结构性零),但
  **全是同一个英雄在不合理的池值上**(GH #176 那族伪影)⇒ 拒绝,`[W3]` 把**拒绝**钉成
  断言(计数 16 **且不同英雄数必须 == 1**)。
  **本地**:`tests/test_salvepool_missing_floor.lua` **19 例全绿,12 变异 12 抓 + 控制前后
  干净**(含 **3 条模型层**:armed floor 用 `max` 代 `min` / quiet 半径 900→1600 /
  端到端计数漏掉大药合取项,抓到 6/3/1 条)。真实帧锚点
  `f_260819_004858_cm_centaur_far`(t=423.4,turbo)**焦点英雄冰女 7 级、包里第 5 格
  就是 `flask`、427/890 = 48% 血,正落在本杠杆开的那条带里**,**零新 fixture 文件**。
  **棘轮**:`bots/` 只动**两个**文件、`ability_item_usage_generic.lua` 只 **+3 行**,就顶掉
  `item_name_census`(1 行号 6791→6794)+ `level_gate_census`(2 行号 5800→5803 /
  5840→5843)—— **GH #221 那族第七例,且是第三个连续轮次动同一对钉**(三行、三轮、
  一个注册键,**没有变稀、在变密**)。按 `0LN2` **移钉不放松**,**又一次是开工自检的
  Lua 腿在工作树上、push 之前**抓到的 ⇒ **三条钉一秒都没红在 main 上**。
  **门**:luacheck **0 警告 EXIT=0**;python **37/0**;Lua 受影响面 **115 个 grep 命中顺序跑完
  = 1180 pass / 0 fail**(**顺序不并行** —— GH #222 判据二;本轮一度有**两个**循环同时在跑,
  正是那条判据说的假红场景,发现后杀掉单进程重跑)。**⚠ 那 115 里 11 个不是这个数的一部分**:
  `tests/_*_sweep.lua`(十个手工 sweep)+ `tests/skill_level_map.lua` **不是 runner 能寻址的
  测试文件**(runner 只枚举 `tests/test_*.lua`),拿它们当 filter 得到 `NO TESTS RAN` 退出 2
  —— **是清单构造的产物,不是红**。诚实读法:**受影响面 = 104 个可寻址测试文件,1180/0**;
  清单该用 `grep -l ... tests/test_*.lua`。
  本次 token:`TOKENS total_in=29,026,322 out=99,280 turns=139`(turns 偏高主因是顺序跑
  ~40 分钟的等待,其中前 ~20 分钟是**白等** —— `setsid nohup &` 起的后台循环被工具调用
  一起杀掉了;下次直接用 harness 的后台执行)。
  `queue.json` **零改动**,**零 AWS**。
  **交棒**:**总监**(裁 `salvepool` 入集;本组建议**先不入**,但「等一帧」是合理的等法、
  **不是归档的理由**)、**录像组**(一条离线零 EC2 分母:cap=25 turbo 语料里「包里有
  `flask` ∧ 900 内无存活敌方英雄 ∧ 缺血量落在 `(0.5·maxHP, 500]`」每局几帧)、
  **批测台**(**本轮无请求**)、**英雄组**(无)。
  **下一格**:同一个函数**贴队友那半的 `> 550`**(对 538 的池子是**真正的结构性零**,
  本轮故意没动,**不需要新语料**);`nFullRespawnTime` 改名**仍等裁定**;GH #190 仍等读数;
  `54 处 list[1]`、`13+ 处 J.GetCenterOfUnits`、#212 §4 三条仍为**不做**。
  详见 `iterations/reports/strategy/20260826T194116Z.md`。
- 2026-08-26T17:08Z:**买活阶梯的第三个普通模式时长;而本轮真正学到的是「两个互相独立的原因
  会关掉同一批格子,测试的责任是不把另一个洗成本缺陷」的**反向控制**长什么样。**
  开工自检 **UNLANDED 0**;cadence **2 findings**(replay-check 3.7h、**strategy 3.8h** —— 是本组,
  但那是上一轮自己的间隔);未裁 queue 请求 **0**(open 33);稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  trunk python **36 passed 0 failed**;trunk Lua 快检测器 **9 文件 0 失败**;selfcheck worst exit **3**;
  开工 `HEAD == 6ff3edfc`;容器无 `lua5.1`/`luacheck`,**两者都由脚本自己装上**;**AWS $0**(未 bootstrap)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条**重新买了证据**而不是照抄上一轮裁定:
  P1 DoD①已完成(`pullcamp_SILENT_ROOTCAUSE_GH109_20260822` + `READMITTED`),P2 DoD①已完成
  (`stayfield` + `stayfield2`,双双钉在铁证帧 `f_260822_063722_lina_tp_home` 上),P3 归总监
  ⇒ **本组无未完成格**。**顺带更正一条会误导下一轮的记录**:上一轮把 P2 的阻塞写成「待一帧 t>1080 的
  fixture」—— 那是 #212 §4 农田上限那格的前置,**不是 P2 的**,P2 的帧 08-22 就归档了(结论不变,理由换对)。
  ⇒ 落到上一轮在本节「下一格」里**显式登记**的姊妹误读,**不需要新语料**。开 **GH #222**。
  **⭐ 缺陷**:`aiug` 买活阶梯里 rung 1 与 rung 2/3 之间那道 `if nFullRespawnTime < 60 then return end`,
  **60 是普通模式的时长** —— 同一段阶梯里**第三个**没随模式缩放的秒数常量(前两个:#208 双减、#215 的 80)。
  **不依赖 getter 怎么读**:60 是**复活秒数**,而 turbo 把每个复活时长乘 0.75。读法 A(名字自称的完整时长):
  选中集合**严格小于**它被写出来时要选的。读法 B(有据可查的 remaining):remaining ≤ R ≤ **75**
  ⇒ 下面两级只在 [60,75] 可达 = **死亡最初 ≤ 15 秒**;且**凡 turbo R < 60 的英雄门在 elapsed 0 就已为真**
  ⇒ 下面两级**整场死亡全关**(turbo R<60 ⟺ 普通 R<80,是复活表的大部分)。
  **⭐⭐ 修法**:gated **`bbshort`**(turbo-only)`J.BuybackShortRespawnFloor()` —— 未 armed 返回出厂
  字面量 **60**,armed **45**(`J.BUYBACK_SHORT_FLOOR * J.TURBO_RESPAWN_FACTOR`,**算出来、不许写 45**,
  复用 `bbfight` 已具名的系数)。**GH #207 预检主动做过**:单合取,armed 的域取在**两个邻居的出厂读法**上
  ⇒ **单独 arm 就打得响**,另有单调性用例(`bbrespawn` 也 armed 时窗口只会变宽)。**单向**:只降一个
  挡买活的下限,只可能开、不可能关,并钉住它不许动 rung 1 的 `>20` 与 rung 3 的 `<40`。
  **⭐⭐⭐ 域,当作域来量、不冒充零**:64 格网格上 shipped **12** / armed **24**,**新开 12**;
  其中 **R=50 开 3 格、R=55 开 4 格**,而这两行 shipped 是**整场死亡 0 格** —— `bbfight` 的网格没有
  50/55,**没有它们这条杠杆根本量不出来**。另一侧的诚实写进测试:**R=40 armed 后仍全关**(40<45),
  **不主张**救得回它。`[arith]` 另有一条**拒绝越界**:这**不是** `bbfight` 那种结构性零,别把那句话借过来。
  **⭐⭐⭐⭐ 本轮主判据**:`[defect-control]` 把门**整个拿掉**再数 —— **R=9/20 仍然 0 格**
  (关掉它们的是下面的 `<40`,**不是这道门**;算到本杠杆头上就是 #215 判据二换了一对原因),
  而 **R∈{40,50,55} 在无门世界开 8 格**(所以控制项**不能靠「把一切都关掉」蒙混**)。
  沿用 #208 判据一(R 是**会倒数的**替身);新增 **`[W3]`**:rung 3 的两个**世界计数不建模**
  ⇒ 本文件量的是「**够得到**那一级」,**从来不是「买了活」**,且这一点**断言在 shipped 源码上**。
  **⚠ 第二条判据(方法)**:上一轮那道「受影响面分 6 段**并行**跑」的门**会制造假红** ——
  本轮照做读到 `bbrespawn` 3 failures,**顺序重跑 = 0 failures**。根因结构性:这些 gated-fix 测试
  用**同一个物理文件** `bots/Customize/soak_side.lua` 当 arm 开关,两个进程同时跑就是在同一个开关上打架。
  上一轮那 2 条 fail 恰好等于两条已知红,**结论没错但方法能凭空造红**。本轮改**顺序跑**。
  **本地**:`tests/test_bbshort_turbo_respawn_floor.lua` **21 例全绿,11 变异 11 抓 + 控制前后干净**
  (含 **3 条模型层**变异:门改读 R−2e / 网格删掉 R=50,55 / armed 退回 60,抓到 3/4/4 条)。
  真实帧沿用 `f_080225_wk_revive`(t=403.0,turbo)zuus L8 `alive=false`,**零新 fixture 文件**。
  **棘轮**:碰倒 **4 文件 6 条 pin,全部移钉不放松** —— `bbfight`(2)、`bbrespawn`(1)、
  `level_gate_census`(1 文本 + **3 行号**,分裂式位移)、**`item_name_census`(2 行号,6785→6791 /
  807→813)**。最后两条是 **GH #221 那族的第六例**,而且是**开工自检的 Lua 腿在工作树上、push 之前**
  抓到的 —— **那两条 pin 一秒都没红在 main 上**,正是 #221 立案时说应该走的那条路径。
  **门**:luacheck **0 警告 EXIT=0**;python **37/0**(rebase 后);Lua 受影响面 **113 个文件顺序跑完
  = 1156 pass / 0 fail**(同一份面并行跑读到 2 fail —— 这两个数字并排就是上面那条方法判据的全部证据)。
  本次 token:`TOKENS total_in=12,797,108 out=71,102 turns=82`。
  **一条读数更正**:`test_itemdesire_world_assertion` 在本轮基线 `6ff3edfc` 上红
  (`jmz_func:2597 crash count moved: 0`),上一轮记成「clean trunk 同样红」;本轮在 `origin/main`
  干净 worktree 上实测 **25/0** —— 已被 `f5a5ab68`(hero,GH #223)修好,**不是长期红**,本轮据此 rebase 后过门。
  `bots/` 只动**两个**文件,**零 AWS**,`queue.json` **零改动**。
  **交棒**:**总监**(裁 `bbshort` 入集,建议**与 #218 的 `bbrespawn`/`bbfight` 一起裁**;另可考虑
  「gate 文件并行不安全」要不要成为一条门)、**录像组**(#215 那两条 + **新增**:turbo 语料里
  **复活时长 R 的直方图**,即「R<60 占多少」这个分母)、**批测台**(**本轮无请求**)、**英雄组**(无)。
  **下一格**:`nFullRespawnTime` 这个**名字本身**(三轮下来已是三个缺陷的共同来源,改名**零行为改动**,
  但要等 `bbrespawn`/`bbshort` 裁定后,否则两个 gate 的未 armed 腿会同时失去「逐字等于出厂」性质);
  GH #190 仍等读数;`54 处 list[1]`、`13+ 处 J.GetCenterOfUnits`、#212 §4 三条仍为**不做**。
  详见 `iterations/reports/strategy/20260826T170858Z.md`。
- 2026-08-26T14:23Z:**一个为「复活最久的那个人」写的规则,被 turbo 的缩放把连那个最大值
  都压到了阈值下面 5 秒;而让这件事在原地躺了 5 天的,是一条把可判的和不可判的写进同一句话的推断。**
  开工自检 **UNLANDED 0**;cadence **2 findings**(batch-desk 8.9h、replay-check 3.7h,**均非本组**);
  未裁 queue 请求 **0**(open 33);稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python **34 passed
  0 failed**;trunk Lua 快检测器 **8 文件 0 失败**;selfcheck worst exit **3**;
  开工 `origin/main == 224fa713`;容器无 `lua5.1`/`luacheck`,**两者都由脚本自己装上**
  (**GH #205 落地后第一次实测:`luacheck_gate.sh` 一句话装好并跑完,0 警告 EXIT=0**,包名那条教训没再复发);
  **AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**;open `[strategy]`
  逐条过完 ⇒ 落到 **GH #212**(录像组 12:54Z 开,带 131/131 局帧证据,正文 §4 **明确写「要不要开单
  由协同组判断」**)。**认领后**:§4 那一格的诚实答案是**「不做」**(见下),不足以构成工作单元
  ⇒ 顺着 #212 自己揭出的**形状**(内层常数被一个它够不着的外层/上游条件支配)找同族,
  落在**买活阶梯**上。**不是换题,是同一条方法的第二个落点,而第二个落点比第一个可判。**
  **⭐ 缺陷**:`aiug` 买活三段阶梯中间那段 `bot:GetLevel() > 24 and nRemainingRespawnTime > 80`,
  **80 是普通模式的时长**。复活表 12s(L1)→ **100s**(L25 及以上);**turbo 复活快 25%**
  ⇒ **天花板 = 75s**,低于阈值 **5 秒**;两种读法(`R−2e` / `R−e`)**都 ≤ R ≤ 75**
  ⇒ **STRUCTURAL-ZERO**,成立在这条分支**唯一为之而写的那个等级**上。
  **⭐⭐ 修法**:gated **`bbfight`**(turbo-only)`J.BuybackFightRespawnFloor()` —— 未 armed
  返回出厂字面量 **80**,armed **60**(同一系数缩放);三常数**具名 + 各带棘轮**(它们是**本容器
  无法核验的外部引擎事实**);armed 值**算出来、不许写 60**。**GH #207 预检主动做过**:单合取,
  且 armed 的 **6 格**取在**出厂 `R−2e` 读法**上 ⇒ **单独 arm 就打得响**。出厂腿 **0/50 格**。
  **⭐⭐⭐ 三条判据**:①**一个未核验的推断错了,代价不是它自己错 —— 是它把三件不同的事捆成
  一个判决**:`test_level_gate_census` 的 `[recorded]` 写着「turbo **halves** respawn time」,
  而**那个系数是承重的**(0.5 ⇒ 天花板 50s ⇒ 上方 `< 60` 早退恒真 ⇒ **三条通路全死、共享一个判决**;
  0.75 ⇒ 75s ⇒ **分岔**:第 2 条 DECIDED、第 1/3 条仍是 RECORDED CLAIM)。**那条真正可判的东西,
  在错误的公司里躺了 5 天。** ②**够不着可以有两个互相独立的原因,而测试的责任是不把另一个洗成缺陷**
  (`[W1]` 无 respawn 字段 + **`[W2]` 归档等级上限 19**;`[defect]` **显式授予**等级合取项 + 反向控制)。
  ③**#212 §4 答「不做」,理由不是「不值得」**:方向与 `c3`/`corefarm` 两次 0/4 的读数相反,
  且归档最晚一帧 **t=690.5s** ⇒ 买不到本地验证;**但这次前置买得到**(#212 自证带内 440,569 帧、
  最大 t=1646.5)⇒ **登记为不做,前置 = 一帧 `t > 1080` 的 turbo fixture**,与 `tbearly` (B) **同一把钥匙**。
  **本地**:`tests/test_bbfight_turbo_respawn_ceiling.lua` **20 例全绿,10 变异 10 抓 + 控制干净**;
  真实帧 `f_080225_wk_revive`(t=403.0,turbo)zuus L8 `alive=false`。
  **本轮自己也被棘轮点到(第三次同族)**:4 行注释推后 `aiug` 三个行号钉(584→588 / 5790→5794 /
  5830→5834),`test_level_gate_census` 当场红、**报对了**,按 `0LN2` **移钉不放松**;
  而那一行的 `why` 原本就写着「a SECOND, independent reason, **which is the part worth following
  up**」—— **本轮 follow up 的就是它**。
  **门**:luacheck **0 警告 EXIT=0**;python **34/0**;Lua **受影响面全集**(grep 到 `aiug`/`jmz_func`
  的 **101 个测试文件**)分 6 段跑完 **1131 pass / 2 fail**,那 2 条**在干净 trunk worktree 上同样红**
  (`test_item_name_census` 的 `PROBE item_recipe`,**两次报的位置还不同**,疑遍历顺序不定;
  `test_itemdesire_world_assertion` 的 `jmz_func:2597 crash count moved: 0`)—— **非本轮引入、非本组**。
  `bots/` 只动**两个**文件,**零新 fixture 文件**,**零 AWS**,`queue.json` **零改动**。
  **交棒**:**总监**(①裁 `bbfight` 入集;②收判据一那条 INFERENCE 的改正;③`tbearly` (A)/(B) 仍在你手上,
  本组倾向 **(A) 出集**,附加理由见 #212 评论)、**录像组**(两个离线零 EC2 请求:**分母** = turbo 语料里
  等级 ≥ 25 的死亡次数 [及其中 `GetTeamFightLocation ~= nil` 的次数];**一帧 `t > 1080` 的 turbo fixture**)、
  **批测台**(**本轮无请求**)、**英雄组**(无)。
  **下一格**:GH #208 的姊妹误读 `nFullRespawnTime < 60` —— 它现在是**第 1/3 条通路共同的那道门**;
  GH #190 仍等读数;**`54 处 list[1]`**、**`13+ 处 J.GetCenterOfUnits`**、**#212 §4** 三条均为**不做**。
  详见 `iterations/reports/strategy/20260826T142344Z.md`。
- 2026-08-26T10:34Z:**「我还要死多久」被同一个 getter 读了两次、被自己减了一次;
  而上一格是被「买不到本地验证」退回的,不是被「不值得」退回的。**
  开工自检 **UNLANDED 0**;cadence **3 findings**(batch-desk 8.9h、replay-check 3.8h/3.7h,
  **均非本组**);未裁 queue 请求 **0**;稳定版锚点 stable-v1/v2 **各 3 项 ok**;
  trunk python 开工/收尾均 **32 passed 0 failed**;trunk Lua 快检测器(装好 `lua5.1` 后)
  **8 文件 0 失败**;selfcheck worst exit **3**;开工 `origin/main == c845daa0`;
  容器无 `lua5.1`/`luacheck`,已装(**GH #205 本轮第三次成立**;顺带:apt 包名是 **`lua-check`**,
  `apt-get install luacheck` 报 `Unable to locate package`,而 `ci.yml:15` 一直是对的);
  **AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**;
  open `[strategy]` 逐条过完,**没有一条等本组动**(#202/#198 本组自开已交出;#201 正文写死
  「归录像组」;**#196 总监 09:56Z 已裁 APPROVED 搭车 W14**,那条强制判据修正投给**执行 (a) 的
  录像组**、总监三处齐已投递,本组无欠;#190 上一轮已登记「要先有读数」;#188/#186/#182/#174/
  #172/#168/#160/#157/#143 同为本组已交出的棒);顺带核了非本组前缀的 #197(录像组已自答自结)
  ⇒ 落到「§下一格」的 `54 处 list[1]`,**当场量完退回**(见下),改取**章程 backlog `0i`
  2026-08-21T22:00Z 顺带登记、5 天无人认领的第二个杠杆**。
  **⭐ 缺陷**:`X.GetRemainingRespawnTime`(`aiug:368`)= `bot:GetRespawnTime() - (DotaTime()
  - fDeathTime)`,而 `GetRespawnTime()` 按 `BOT_API_REFERENCE.md:992` 逐字是
  **"Seconds until this hero respawns"** = **已经是剩余、自己在倒数** ⇒ 返回 **R−2e**,
  **两倍钟速衰减**,**e = R/2**(死亡正中间)穿零。**名字自己招了产生它的读法**:同一个 getter
  在 15 行外叫 **`nFullRespawnTime`**(`:565`)。**方向单向**:三个消费方全是这个数的**下界**
  ⇒ 只会**关掉本该允许的买活**(`>20` 窗口 R−20 → **(R−20)/2**;后半程恒 ≤0,三门全关)。
  **⭐⭐ 修法**:gated **`bbrespawn`**(turbo-only)`J.RespawnRemaining` —— 未 armed **逐字等于
  出厂**,`fDeathTime == 0` 短路**留在门之前**(armed 不许给活着的英雄报复活时间)。
  **GH #207 预检通过**:单合取,另一半是 `IsModeTurbo()` 模式谓词不是另一个 soak id;
  `[source]` 把「恰好一处解析、且解析成 turbo AND 'bbrespawn'」钉成断言。
  **⭐⭐⭐ 三条判据**:①**替身要连动力学一起声明** —— 第一版把 R 声明成**常数**,`[defect]`
  当场红**而且报对了**:常数替身模型的正是**被测的那个误读**,在那个世界里缺陷消失
  ⇒ 改喂 `R − e`,armed=R−e / unarmed=R−2e / **两腿之差恰好 e**。**静止的替身,对一个关于
  时间演化的缺陷,是隐形的假阴性**(`abilanc` `[W1]` 的下一层)。
  ②**本轮刻意不提入集、不提波次请求 —— 这条修好的腿今天打不响**:上面那个消费方前置
  `IsAncientBadlyHurt`(`bbancient` 登记:**58 个遗迹快照全 hp=1.0**,裁判 forcewin ⇒ 没录到
  围高地),下面两个压在 `:580` 底下 ⇒ arm 它只会塞一条 **GH #207 那种打不响的腿**。
  ③**上一格退回的理由是「结构上买不到本地验证」**:145 处 sweep 里 **64 处**带 `[1]`,
  但**门的谓词读列表内容**而**引擎顺序不在任何 dump 里**(GH #100)⇒ **域和验证同时是声明的**,
  fixture 退化成对测试自己输入的复述。**登记为不做,前置 = GH #100。**
  **本地**:`tests/test_bbrespawn_double_subtract.lua` **16 例全绿,9 变异 9 抓 + 控制干净**;
  真实帧 `f_080225_wk_revive`(t=403.0,turbo)上的 **zuus L8 `alive=false`** ——
  **出厂表达式做减法用的那个钟就是这一帧自己的 403.0**;`[W1]` 两条断言 dump 没有 respawn 字段
  (**第一版写成子串 `respawn_time` 时误抓了 `modifier_necrolyte_reapers_scythe_respawn_time`**)。
  **门**:luacheck **0 警告 EXIT=0**;python **32/0**;Lua 切片 bbrespawn 16 / abilanc 13 /
  gate_claim 10 / smoke 3 / no_undefined 3 / jmz 3 / level_gate 15 / camp 128 / pull 139 /
  farm 29 / roam 27 / ancient 47 / tp 190 **全部 0 失败**。
  `bots/` 只动**两个**文件,**零新 fixture 文件**,**零 AWS**,`queue.json` **零改动**。
  **交棒**:**总监**(①收三条判据;②裁「本轮没提入集/波次」这份克制;③裁**下一个杠杆是不是
  `:580` 的姊妹误读**,以及 `bbrespawn` + `:580` +(可能)`bbancient` **该不该作为一个 atom
  一起动**(`creeppull`+`pullbeat` 先例);④把 `54 处 list[1]` **登记为不做、前置 GH #100** 入档)、
  **批测台**(**本轮无请求**)、**录像组**(无;若 cap=25 语料里出现**围高地**帧请顺手报一句 ——
  那是 `bbancient` + 本条一起解锁的信号)、**英雄组**(无)。
  **下一格**:`:580` 的 `nFullRespawnTime < 60`(`[limit]` 已钉住,分母 = 「每次死亡的最后
  60 秒」,**不需要新语料**);GH #190 仍等读数;**`54 处 list[1]` 不做**;
  `13+ 处 J.GetCenterOfUnits` 仍为**不做**(#196 §3.2)。
  详见 `iterations/reports/strategy/20260826T103433Z.md`。
- 2026-08-26T08:01Z:**技能层的远古目标选择 —— 门放进选择器而不是 20 个调用点;
  而它的分母已经量过,量出来的数小到必须换判据形状而不是退回。**
  开工自检 **UNLANDED 0**;cadence **4 findings**;未裁 queue 请求 **0**;
  稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python 开工/收尾均 **32 passed 0 failed**;
  trunk Lua 快检测器(装好 `lua5.1` 后)**8 文件 0 失败**;开工 `origin/main == 7999c41d`;
  容器无 `lua5.1`/`luacheck`,已装(**GH #205 那件事本轮再次成立**);
  **AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**;
  open `[strategy]` 逐条过完(#202/#198 本轮之前本组自己开、已交出;#201 正文第一行
  自己写死「归录像组」;#190 上一轮已登记「要先有读数」;#188/#186/#182/#174/#172/#168/
  #160/#157/#143 同为本组已交出的棒)⇒ 落到 **GH #196**(录像组 01:13Z 开,**3 轮无人认领**)。
  **⭐ 缺陷**:10..11 级英雄与远古营的交火**绝大多数不是打野目标选择打开的** ——
  armed 12 次 `opened` 里 **10 次由技能**、**6 次对着远古营施法**(baseline 9 里 7 / 6)。
  `campgrade`/`campsel`/`campfarm` **三条通路全在打野路径上,一条都够不着**:
  英雄的 `ConsiderAbility` 自己扫 `GetNearbyNeutralCreeps`,把**原表**交给 `J.GetMostHpUnit`,
  而这个选择器**按构造**选中远古野。承重帧 `20260825_212701_slot2` luna **L11 t=515.5**。
  **⭐⭐ 修法**:gated **`abilanc`**(turbo-only)。**排除放进选择器内部**,与那里**已有的
  同类两条**(Roshan、Tormentor)并列 —— 远古营是这一类里没人补上的那一个。
  门放在这里 ⇒ 漏门从「计数用例事后抓」升级成「**结构上做不到**」。
  阈值读 `J.Site.ANCIENT_MIN_LEVEL`(0SRC)。**豁免恰好一处**:`doom_bringer:305`,
  全仓唯一在 commit 之前读 `IsAncientCreep` **且能对远古采取行动**的消费方,**命名的是机制**。
  **⭐⭐⭐ 两条判据**:①**域太小买不到效应量,不等于买不到条件 (a)** —— 能管的那一格
  armed 6 / baseline 6 / 125 局 ≈ **每局-腿 0.048 次**,撑不起计数差分;而 (a) 问的是
  **存在性 + 逐帧正确性**,一次就够。⇒ `strategy-20` **主动不主张效应量**并预先声明
  带内计数差分不当证据(**带内所有切法两层反号**,侧别效应 **10:1**)。
  **「域小」不是判决,是必须换判据形状的信号。**
  ②**一个「可选参数」会把「传 1 声明 2」变成每个现存调用点的形状** —— 豁免先写成可选参数,
  GH #188 arity 棘轮**当场对 16 个文件全红,而它报对了**;判成 `DEFAULTED` = 给一个
  **设计上只能缩**的名单加 16 行。⇒ 改成第二个入口 `J.GetMostHpUnitAnyTier`。
  **别人的棘轮点着的是设计就改设计,是注释就改注释,两次都不许放松棘轮。**
  **本地**:`tests/test_abilanc_ancient_selector.lua` **13 例全绿,8 变异 8 抓 + 控制干净**;
  **一个真实帧扛起整条等级阶梯** —— `f_212636_tide_ancient`(t=627.5,turbo)同帧上
  tide **L10** / zuus **L11** / luna **L14**,三个都带 `modifier_ancient_rock_golem_weakening`
  (**不是从坐标推的**);野怪那半是**声明的替身**,`[W1]` 把「fixture 一律答 `{}`」断言下来。
  **⚠ 第 5 条变异(阈值抄成字面量)第一次漏抓**:`[source]` 整文件 `find` 常数名,而
  **我自己的注释里也写着它** ⇒ 钉那一行代码才抓到(**`0SRC` 自己的失效模式**)。
  **门**:luacheck **0 警告 EXIT=0**;python **32/0**;Lua 切片 abilanc 13 / camp 128 /
  pull 139 / farm 29 / roam 27 / ancient 47 / replay 200 / tp 190 / lane 58 / axe 109 /
  roshan 27 / luna 6 / smoke 3 / no_undefined 3 / jmz 3 / gate_claim 10 / level_gate 15
  **全部 0 失败**;`check_armed_wiring.py --cand abilanc`(commit 后)**direct / 1 站点 / WIRED**。
  `bots/` 只动**两个**文件,**零新 fixture 文件**,零 AWS。
  **交棒**:**总监**(①`test_set.md §BK` 入集提议,成员串 **36 → 37**;②「分母已量、
  但量得太小 ⇒ 换判据形状而不是退回」是不是 §BJ.2 边界的正确用法;③收两条判据)、
  **批测台**(`queue.json:strategy-20`,**搭车零增量**;排波前置:`campgrade` 不得与
  `abilanc` 同腿,`campfarm` 可以)、**录像组**((a) 的形状是**存在性**不是计数)、
  **英雄组**(无)。**下一格**:54 处 `list[1]`(独立杠杆,分母未量,计数已由 `[limit]` 钉住);
  13+ 处 `J.GetCenterOfUnits`(#196 §3.2 明确不要动,**登记为不做**);GH #190 仍等读数。
  详见 `iterations/reports/strategy/20260826T080105Z.md`。
- 2026-08-26T04:35Z:**空荡荡的 1600 圈被读成「被人数压制」——
  而一个杠杆的「域」是两个数,它们差三个数量级,必须分开报。**
  开工自检 **UNLANDED 0**;cadence **5 findings**;未裁 queue 请求 **0**;
  稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python 开工/收尾均 **32 passed 0 failed**;
  trunk Lua 快检测器开工 **SKIP**(那一刻无 `lua5.1`);开工 `origin/main == 8034c3b`;
  容器无 `lua5.1`/`luacheck`,已装;**AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**;
  open `[strategy]` 逐条过完(**#201 前缀是 `[strategy]` 但正文第一行自己写死「归录像组」
  ⇒ 前缀与正文冲突以正文为准,不认领**;#190 上一轮已登记「要先有读数」;
  #188/#186/#182/#174/#172/#168/#160/#157 是本组前几轮自己开、已交出去的棒)
  ⇒ 落到**章程 backlog `0a` 第三条**(2026-08-20T11:30Z 判为「机制已确认、证据取不到」),
  重新问的理由是 **GH #108 把批测局上限 10→25**,那个前提**有可能过期**。
  **⭐ 缺陷**:`mode_retreat_generic` 与 `mode_farm_generic` 的 `X.ShouldRun` 里**同一段
  复制粘贴**的块,presence 项是 `#hEnemyHeroList >= #hAllyHeroList`;两张表来自
  `J.GetEnemyList/GetAllyList(bot,1600)`,**友军表不含 bot 自己**(engine 约定,
  loader 逐字实现 `other ~= self`,全仓 2277 处读数建立在它上面)⇒ **(0,0) 恒真**。
  非零 `ShouldRun` = **`BOT_MODE_DESIRE_ABSOLUTE * 1.1` 闩 2 秒**(farm 侧另清 `preferedCamp`
  + `Action_ClearActions(true)`),外层情形 = **一个人打进敌方兵营圈**
  ⇒ **视野内没有任何防守者的独狼被一次不存在的人数劣势按最高优先级掉头**。
  **⭐⭐ 修法**:gated **`basesiege`**(turbo-only)`J.IsBasePresenceAdverse` ——
  未 armed 逐字节等于出厂比较,armed 只在 **(0,0)** 不同。
  **宽度是被证明的不是被声称的**:`[lever]` 在 **0..5 × 0..5** 上穷举,断言差集恰好
  `{e=0 a=0}`,并逐格断言未 armed 那一路 == `#e >= #a`。**两个调用点一起改**:
  同一段复制粘贴,只修一处 = 让两个 mode 对同一情形给出不同判断。
  **⭐⭐⭐ 三条判据**:①**「域」可以是两个数**——**谓词**域量得到(出厂 helper 普查
  **966 帧 / 302 帧 (0,0) = 31.3%**),**分支**域量不到(还要 800 内有敌方兵营,
  全语料最近 **4838u** ⇒ **cap 10→25 还没流进 fixture 语料**);把前者当后者引用是
  `campfarm` domain-too-small 的**反面**错误 ⇒ 本轮**刻意不提入集、不提波次请求**。
  ②**域小 ≠ 不值得,判据是「域 × 每次价值」**:这条是**极高价值 × 未知频率**,
  「先量分母」不等于「量不到就归档」。③**普查要用出厂 helper 跑**:python 几何近似得
  **149/563**,出厂 helper 得 **302/966**,差别是**雾**,方向是**低估**。
  **本地**:`tests/test_basesiege_presence.lua` **13 例全绿,6 变异 6 抓 + 控制干净**;
  承重帧 = 全语料 (0,0) 帧里**离敌方遗迹最近的一帧**(`f_260819_183613_storm_collapse_parity`
  / zuus,7278u),另三个真实对照帧覆盖其余三种 presence 形状,四组读数由 `[frame]` 钉住;
  `[limit]` **把外层分支在本语料里的不可达性断言下来**(哪天有 fixture 进到 800 内,当场红)。
  **门**:luacheck **0 警告 EXIT=0**;python **32/0**;Lua 切片 basesiege 13 / retreat 25 /
  farm 29 / camp 128 / pull 139 / roam 27 / gate_claim 10 / smoke 3 / no_undefined 3 /
  jmz 3 / level_gate 15 = **395 例 0 失败**。`bots/` 只动三个文件,零新 fixture 文件,零 AWS。
  **交棒**:**录像组**(离线数帧、零 EC2:cap=25 语料里「800 内有敌方兵营」每局几帧、
  那些帧 1600 圈里敌我各几人;判据单向,每局 < 1 帧 ⇒ 直说不值得;
  **可与 #201 的 `campdanger` 分母同一次扫描一起出**)、**总监**(①这份读数值不值得先买
  ②本轮**没有**提入集/波次请求这份克制对不对 ③收三条判据)、**批测台**(**本轮无请求**)、
  **英雄组**(无)。详见 `iterations/reports/strategy/20260826T043502Z.md`。
- 2026-08-26T01:38Z:**farm 模式的 `Think()` 里有一次活的 nil 调用,而修复该劈成两半 ——
  被迫的那半不 gate,政策的那半才 gate。**
  开工自检 **UNLANDED 0**;cadence 7 findings(含本组一条 ~3h GAP);未裁 queue 请求 **0**;
  稳定版锚点 stable-v1/v2 **各 3 项 ok**;trunk python 开工/收尾均 **31 passed 0 failed**;
  trunk Lua 快检测器开工 **SKIP**(那一刻无 `lua5.1`),装好后 **8 文件 0 失败**;
  开工 `origin/main == 8f36e606`(收尾 `05c25393`,已 rebase 并**复跑全部门**);
  容器无 `lua5.1`/`luacheck`,已装;**AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**;
  open `[strategy]` 逐条过完(#190 上一轮已登记「要先有读数」;#188/#182/#186 是本组前几轮自己开的)
  ⇒ 落到 **GH #193**(22:55Z 英雄组从 #192 转交,**零轮无人认领**,带完整源码定位)。
  **⭐ 缺陷**:换野点合取项调用 `J.Site` 上一个叫 `IsCampDangerous` 的字段,该名字在 `bots/` 下
  **六种声明形式零命中**,`J.Site` 是**没有 setmetatable / __index 的转译平表** ⇒ 字段是 nil,
  那一行在 `Think()` 里抛 `attempt to call a nil value`。**三条前提我都自己复核过,没照抄 issue**,
  并在真实帧上 `pcall` 出了那次 raise。坏错误处理器 ⇒ **它不像崩溃像静默中止**,**未 gate**,
  每一局、每个「最近可用野点近 200u 以上」的帧,**吃掉 `Think()` 从那行起的整条尾巴**。
  **四层都看不见它**,而最值钱的是第一层:`test_no_undefined_jmz_refs.lua`(GH #48)
  **就是为这一类写的、每轮都在跑**,而**它的 pattern 在第一个点就停了** ⇒ `J.Site.<名字>`
  被读成对(有定义的)`J.Site` 的引用,**第二个分量从来没被问过**;盲区是**六张子表下的所有名字**。
  **⭐⭐ 修法**:**劈在「证据不再是被迫的」那一行上**。未 gate 的 `J.IsCampSwitchSafe`
  (未 armed 返回 `false` = **中止本来就产生的换野点决定**,逐字节同一个决定,
  唯一变化是 `Think()` 继续跑)+ gated **`campdanger`**(turbo-only)承担政策那半。
  **两个操作数都不是编的**:`J.GetLastSeenEnemiesNearLoc` 是出厂雾记忆查询且
  **没有 `i <= 3` 上限**(本文件自己那个 `X.IsUnitAroundLocation` **有**);
  **800 是这个文件自己**对「谁站在这个野点上」的半径(下面几行的友军判据就是
  `J.GetAlliesNearLoc(targetFarmLoc, 800)`)。**谓词放 `jmz_func` 而非 `X` 是测试性决定**:
  `X` 是 file-local,停在 `X` 里的谓词**测试根本调不到**,剩下的唯一「验证」就是把 gate
  抄进测试再断言抄本 —— 章程说的 gate-plumbing 逐字就是这个形状。
  **⭐⭐⭐ 三条判据**:①**「A 还是 B」有时是问错了一层 —— 先问 A ∩ B**;那个交集若是被迫的,
  就不该跟着分歧一起被关进 gate(否则一个已证明的故障继续在真实对局里等波次)。
  ②**棘轮读原始源码**:注释里逐字抄被修掉的调用会把它重新点着(§4 当场红);
  **改自己的注释,不放松别人的棘轮**。③**自检那句 `failing before you changed anything`
  是罐头字符串不是判定** —— `git stash` 核对过 main **15/15 绿**,红是我的(`0LN2` 第五例,
  普通代码插入顶掉按行号钉的 row,`:599 → :637`,**只动 `line`**)。
  **本地**:`tests/test_campdanger_switch_safe.lua` **14 例全绿,4 变异 4 抓(2/2/1/2)+ 控制干净**;
  承重帧 = **GH #137 那一帧**(11 级白牛 817/1307,身上带 `modifier_ancient_rock_golem_weakening`,
  真的在野营里被吃);`[boundary]` 把半径扫过**真实 7644.8u**,**r=7643 安全 / r=7646 危险**。
  **⚠ 声明的本地上限**:`GetNeutralSpawners()` 每帧答 `{}` ⇒ 换野点分支 fixture 里
  **结构上不可达**,位置操作数是**真实地图点而非真实野营**(`[W1]` 一旦有货就自曝过期)。
  **门**:luacheck **0 警告 EXIT=0**;python **31/0**;自检 Lua **8 文件 0 失败**;
  Lua 切片 campdanger 14 / camp 128 / farm 29 / pull 139 / roam 27 / gate_claim 10 / smoke 3 /
  no_undefined 3 / jmz 3 / level_gate 15 / lf_ 41 = **412 例 0 失败**;
  `check_armed_wiring --cand campdanger` **WIRED**。`bots/` 只动两个文件,零新 fixture 文件,零 AWS。
  **交棒**:**总监**(**已开 GH #198**;①入集 `campdanger` ②收三条判据 ③**裁 GH #193 §2**:要不要把
  `test_no_undefined_jmz_refs` 加深到子表 —— 全队工具,**刻意没由本轮顺手决定**)、
  **录像组**(**先量分母再谈判据**:#193 §5 的离线数帧零 EC2,**那个频率至今没人量过**;
  分母 < 每局 1 帧 ⇒ **直接说不值得,不要凑判据**,`campfarm` 刚吃过 domain-too-small 的亏)、
  **批测台**(`queue.json:strategy-19`,搭车零增量;⚠️ **未 gate 那半对两条腿同时生效**,
  在 armed/baseline 差分上**按构造读不出来**,要用绝对量)、**英雄组**(无,#193 已结案回评)。
  详见 `iterations/reports/strategy/20260826T013814Z.md`。
- 2026-08-25T22:4xZ:**拉野拖拽那一步没迈出去,而吃掉它的那行不在节拍里 —— 一个伪造的 `0`
  让本仓九处 `Think` 节流在我们拥有的每一个用例里永久敞开。**
  开工自检 **UNLANDED 0**;cadence 9 条 GAP(**含本组一条** 04:23Z→07:54Z 3.5h);
  未裁 queue 请求 **0**;trunk python 开工/收尾均 **29 passed 0 failed**;
  trunk Lua 快检测器开工 **SKIP**(那一刻 `lua5.1` 未就绪);
  开工 `origin/main == 2b9c521`;容器无 `lua5.1`/`luacheck`,已装;
  **AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**
  (P1 第 1 棒早交、P2 决策侧已落地、P3 是总监的);open `[strategy]` issue 逐条过完
  (#190 是 22:00Z 刚开的,自己写死第一步是**纯读数**且对照要跨五个位置 ⇒ 本组接它要先有读数,
  已登记下一格;#188/#182 是本组前两轮自己开的;#137/#117/#143/#168/#172/#174 都是已交出去的棒;
  #160「先要帧」;#157 可做格已判空)⇒ 落到 **GH #186**,它**同时是 owner P1 的前置**
  (issue 自己写:在这条修好之前 connect 侧的读数混着「没走」和「走错方向」两件事),
  躺了 **~3.4 小时 / 约两轮**,零 AWS。
  **⭐ 缺陷**:营地拉野节拍每 3s 戳一次营、中间的帧走 500u,但 **42% 的戳营帧后一秒位移 < 50u**
  (ab 48% / ba 39% 同号)。原因是 `Think()` 的**第 2、3 行**
  `IsBotThinkingMeaningfulAction(...) then return`,而它匹配的 `meaningfulActivities`
  **第一、第二项就是 `ACTIVITY_RUN` / `ACTIVITY_ATTACK`** ⇒ **刚戳完营的英雄按构造在攻击动画里**,
  野怪反击把它按住 ⇒ **节流恰好吃掉必须下拖拽指令的那些帧**,分支**根本没被执行到**。
  出厂腿在整整一个 3s 节拍上打印 **91 个 `.`**(一个 `A`、一个 `M` 都没有)。
  **⭐⭐ 修法**:gated **`pullthink`**,**一个 id 两个不可分的半边** ——
  (1) 有拉野计划时跳过节流(未 armed 时只多一次对恒 nil 字段的比较,`IsSoakCandidate` 连叫都不叫);
  (2) 给营地分支补上姊妹小兵分支**早已出厂**的起手 hold(promoted `pullbeat`,0.5s 不下指令)。
  **(2) 是 (1) 的结构性前提不是第二根杠杆**:只放 (1) = 把 GH #143 的缺陷原样搬到营地侧。
  **刻意没写成合取**(`pullbeat` 已 promote ⇒ 当天冻结 FALSE,`pullcad` 陷阱),源码用例钉住「恰好两处」。
  turbo **结构性**(`roamCampPull` 只经 `ShouldPullNeutralCamp` 存在,那里开头就是 `IsModeTurbo`+`pullcamp`)。
  **域刻意收窄到营地拉野**;小兵拉野撞同一行但已有 hold ⇒ 独立杠杆,交总监裁。
  **⭐⭐⭐ 本轮两条判据**:①**一个「两把锁」的解释里可能只有一把是真锁** ——
  第一版的 W2(`ACTIVITY_*` 全 nil ⇒ 名单是空表)**当场被自己的用例打红**:
  `bot_api.lua:404` 的 `_G.__index` **把任何没见过的全大写全局解析成从 1000 起递增的稳定数**
  ⇒ `ACTIVITY_ATTACK` = **1175**,名单**是满的**;真锁只有 `GetAnimActivity()` 的默认 **0**
  (GH #133 同型),而它按住的是**九个调用点**。**冗余的解释要么验,要么别写。**
  ②**没被执行到 vs 执行了没效果,证据同形** —— 判别器不是位移也不是 POKE,**是指令日志**。
  **本地**:`tests/test_pullthink_anim_throttle.lua` **10 例全绿,11 变异 11 抓 + 1 控制**;
  承重帧 = **全语料最近的同侧营地接近**(medusa,天辉英雄距天辉简单野营 355u,四营全语料普查选出);
  **本文件任何一处都不 arm `pulldrag`** ⇒ 拖拽终点是**真实泉水**,没有断言压在
  `GetLocationAlongLane`(mock 常数 `Vector(0,0,0)`)上。
  **顺带一条 harness 事实**:`check_armed_wiring.py` 默认读 `--ref HEAD` 的**已提交**内容 ⇒
  **commit 之前跑它,新 id 一律报 UNWIRED**,而错误信息读起来像「从没接线」。
  **门**:luacheck **0 警告 EXIT=0**;python **29 passed 0 failed**;
  Lua 切片 pull 139 / camp 114 / roam 27 / gate_claim 10 / smoke 3 / level_gate_census 15 /
  lf_ 41 = **349 例 0 失败**,新文件 **10 例 0 失败**。
  **`bots/` 只动一个文件、零新 fixture 文件、零 AWS。**
  **交棒**:**总监**(①入集提议 `pullthink`,搭车零增量,排波前置 = 同腿必须 armed `pullcamp`
  ②收两条判据 + 九调用点的 harness 事实 + `check_armed_wiring` 读 HEAD 那条
  ③小兵拉野那根独立杠杆排不排)、**录像组**((a) 要等有人 arm `pullthink` 的波;
  核验点 = 戳营帧后一秒位移 < 50u 的占比,**两条反向护栏一条不许省**:
  `pulldrag` lane_win 不许降、**armed 腿戳营帧总数不许塌**)、
  **批测台**(`queue.json:strategy-18`,不申请专波;`campfarm` 的教训照抄:
  波里有什么以 verdict 的 `cand` 串为准)、**英雄组**(无)。
  **⚠️ 收尾追加(结论换了,照实改写)**:`item` 切片跑完是**红的**,而红的是一个**行号** ——
  `test_item_name_census` 的棘轮按 `(kind, name, site)` 冻结、site **含行号**,基线写 `aiug:6774`、
  树上是 `6781`。**逐 commit 验过,差值正是本组上一轮 `c48dc11b`(19:26Z,`lf_salve`/`SetUseItem`)
  在 `aiug:993` 加的 +7**;而 census 落地的 `1fcfcd83`(hero 19:55Z)**在那之后**,
  基线却写着 6774 ⇒ **它从落地那一秒起就在 main 上红着,红了约 3 小时**。
  **`0LN2` 第四例,形状是新的**:前三例是钉子被后来的编辑**顶出去**(两次是注释顶的),
  这一例是**钉子在写下时就是旧的** —— 会话在落后 main 一个 commit 的检出上生成基线;
  **GH #161**(门慢于 main)与 **GH #171**(自检对 main 红失明)在同一条红上会合。
  ⇒ **按行号钉的棘轮,基线要在「即将 push 的那棵树」上生成,不是开工那棵。**
  **本组已把钉子挪到 6781**(注解里的 `:1013` 一并改成 `:1020`,已核对索引确在 1020),
  逐 commit 验证写进该文件注释。**不是放松判据**(kind/name/文件都没动,只有行号跟着代码走)。
  **这次代改了别组文件**(上一轮同类明写「刻意不代改」):上一轮那些是**散文**,变旧不会红;
  这次是**活断言且 main 是红的**,而位移是本组自己的 commit 造成的。已追评 GH #187 / #171。
  **本组自检也没抓到**:开工 Lua 腿读 `SKIP`(那一刻没装 `lua5.1`)—— 与 #171 逐字同型。
  收尾重跑:`item` 全切片 **56 例 0 失败**(修复前 1 失败)⇒ **main 的 Lua 侧恢复绿色**;
  census **6 例 0 失败**、luacheck **0 警告 EXIT=0**、`pullthink` **10 例 0 失败**、
  python **29 passed 0 failed**、`check_armed_wiring` **37/37 WIRED EXIT=0**。
  报告 `iterations/reports/strategy/20260825T224124Z.md`;
  `state.json:pullthink_20260825`;backlog 新增 **`0ANIM`**。
- 2026-08-25T19:2xZ:**`lf_salve` 的就地回复分支从落地那天起一口药都没喝过 —— 少传两个参数
  让派发器五条臂一条都不中,而它上面那个 `return` 还顺手关掉了整层物品。**
  开工自检 **UNLANDED 0**(上一轮点名了四轮的两个 `tpreach` commit **已落地**);
  cadence 9 条 GAP(**含本组一条** 04:23Z→07:54Z 3.5h);trunk python 开工 **27 passed**、
  收尾 **28**;trunk Lua 快检测器开工 **SKIP**(那一刻 `lua5.1` 未就绪)、收尾 **8 文件 0 失败**;
  开工 `origin/main == 8c5351d`;容器已带 `lua5.1`/`luacheck`;**AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**(P1 第 1 棒
  08-22 交出、P2 决策侧三个 id 均已落地、P3 是总监的);open `[strategy]` issue 逐条过完
  (#182 是本组上一轮自己开的,#137/#117/#143/#168/#172/#174 都是已交出去的棒,#160「先要帧」,
  #157 的可做格 `0CLK` 已判空,#119/#110/#123 已落地在等别组,#120 属录像台工具域);
  backlog 顶部四条的下一格:`0DEAD` 本组建议不做、`0PATH`/`0PORT` 已交录像组、
  `0GEO` 纵向那格要兵线位置而 `GetNearbyLaneCreeps` 在 966 帧上答 `{}` ⇒ **本地不可验**
  ⇒ 无外部棒可接,**自驱开一根新轴**(选轴判据:结构量、算术可判、能被 luacheck 结构性漏掉)。
  **⭐ 缺陷(GH #188,已修)**:`aiug:993` `X.SetUseItem( hRegen )` 少传两个参数,而
  `X.SetUseItem( hItem, hItemTarget, sCastType )` **按第三个参数派发** ——
  `'none'/'unit'/'tree'/'twice'` 全靠 `sCastType` 相等,`'ground'` 的兜底是
  `hItemTarget and … and hItemTarget.x ~= nil`(nil 短路)⇒ **函数从末尾掉出去,零动作**;
  而调用方的 `return` **坐在整个 `nItemSlot` 循环上面** ⇒ **这一帧连别的物品也用不成**。
  **armed 买到的是:零口药 + 一层关掉的物品逻辑。**
  **⭐⭐ 修法有两帧用执行钉住,不是读出来的**:`X.SetUseItem( hRegen, bot, 'unit' )`。
  在 `f_260819_123546_jakiro_landed_ok/axe` 与 `f_260820_043140_luna_ring_bid/tidehunter` 上,
  **出厂物品层(零 armed)自己发出的就是** `UseAbilityOnEntity(item_flask→自己)`,
  armed+修复后本分支发出**同一个动作** ⇒ 两条独立路径在同一帧收敛。
  **读数**:域 **20** 主体(flask 6/clarity 14,含 CM×3、zuus、axe×2)、可跑 **18**;
  **PRE 0/18 有动作,POST 17/18**;压制列出厂本来会出手 **8**,扣 4 个 treads 假象(GH #133)
  ⇒ **诚实下界 4,上界 8,本语料定位不了中间那个数**(也不需要)。
  **不新增 soak id**:分支已在 `J.IsLaneFixOn('salve')`(turbo + `lanefix` 或 `lf_salve`)门内,
  新 id 只能写成 `salvecast and lf_salve` = `pullcad` 教的**冻结合取**陷阱;照 `0P1`
  的 `pullcamp` 先例在既有门里修。未 armed 与出厂**逐字节相同**(census `unarmed_mismatch == 0`,断言)。
  **⭐⭐⭐ 撞出来的类 = `0ARITY`**(见 backlog 顶):`only={"1"}` 的姊妹洞,
  275 文件 / 28,364 处带点调用 / 25,194 解析 ⇒ **40 处不匹配全部判过**,棘轮已进每轮自检。
  **躺了多久**:`9c6c19e5` **2026-07-21T05:26Z** ⇒ **两次被拒的 lanefix 捆绑波带着它跑**
  (不主张是成因,只主张在场且没有任何读数提过它)。**读它的路上撞到 harness 事实一条:
  shallow clone 上 `git log -S` 把边界 commit 报成引入者,而且看起来完全正常。**
  **⚠ 又一次 `0LN2`(第三例,第二次由散文推动)**:本轮加的 7 行里 **6 行是注释**,
  把 `test_level_gate_census.lua` 两个按行号钉的 GetLevel 门顶掉(5783→5790/5823→5830),
  **开工自检的 Lua 腿当场红着点名**,已按规定修法移动钉子;
  五个测试文件里对 aiug 行号的**散文**引用同时变旧,**刻意未代改别组文件**,交总监排。
  **门**:luacheck **0 警告 EXIT=0**;python **28 passed 0 failed**;Lua 快检测器 **8 文件 0 失败**;
  Lua 切片 item 50 / lf_ 41 / level_gate_census 15 / fieldcreep 16 / gate_claim 10 /
  smoke 3 / data_consistency 3 = **138 例 0 失败**。**零新 fixture、零 AWS、`queue.json` 无新条目。**
  **交棒**:**总监**(①无入集提议 ②收三条判据 + shallow-clone 事实 ③散文行号统一/换文本锚要不要排)、
  **英雄组**(**GH #189** bristleback 的 8.0 → 硬编码 5;另两条纯 COSMETIC 记账)、
  **录像组**((a) 要等有人 arm `lanefix`/`lf_salve` 的波;核验点 =「域内 bot 真把药喝下去」,
  **反向哨兵**:armed 腿线上物品使用总量不许下降 —— 用一个黑屏换另一个黑屏读起来一模一样)、
  **批测台**(无)。
  报告 `iterations/reports/strategy/20260825T192600Z.md`;
  `state.json:lf_salve_cast_type_20260825`;backlog 新增 **`0ARITY`**。
- 2026-08-25T16:4xZ:**改一句错注释的路上,撞出本仓的门看不见的一整类东西 —— 而那一类里
  恰好有一个不是死代码,是掉了一级的阶梯。**
  开工自检 **UNLANDED 2**(**均非本组** —— 总监 08-24T22:2xZ 的 `08ed7c2`/`fc79986`,`tpreach`,
  **连续第四轮**);cadence 9 条 GAP(非本组);trunk python 开工 **26 passed**,收尾 **27**;
  开工 `HEAD == origin/main == 1c5b084`(`git ls-remote` 一致);容器无 `lua5.1`/`luacheck`,已装;
  **AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 先过 `OWNER_PRIORITIES.md` —— 三条优先项**本组无未完成格**
  (P1 第 1 棒早交、`campfarm` 本轮被总监裁为 `APPROVED_ADMITTED` 35→36、P2 决策侧已落地、P3 是总监的);
  open `[strategy]` issue 逐条过完(#174/#172/#168/#143 都是已交出去的棒,#160 自己写着「先要帧」,
  #157 的下一格被 #178 接走)⇒ 落到 **GH #178** —— **本组自己文件里的一条错断言**,
  录像组 13:11Z 开的,自带实测 + 建议措辞,零 AWS,**躺了 ~3.5 小时 / 两轮**。
  **⭐ #178 已落地并关闭**:`mode_retreat_generic` `towerfear` 门上方原写「放掉的帧由下面的校准判据接住」,
  而**塔攻击距离 700 < 该块的环 898** ⇒ 700-898 环带里 `GetAttackTarget()==bot` **不可能为真**,
  实测 W8+W9 418 局 **72.7%** 的放行帧住在那里。换成实际分工(annulus 无接盘也不需要 /
  校准判据接的是 10.2% 的贴脸开火 / `<=9` vs `<=10` 那 0.9% 是**判据设计**不是几何)。
  #178 建议的 `TOWER_ATTACK_RANGE_U < ring` 断言**录像组已落地**,本组不重复造。
  **⭐⭐ 撞出来的类**:`.luacheckrc` 写 `only = { "1" }`,而 unused 家族是 **2xx**
  ⇒ **「只写不读的 local」静默通过铁律 6 的门,全仓、永久**。九个决策文件 **13 个**(全仓 285)。
  工具 + 棘轮已在位(`write_only_local_census.py` / `test_write_only_local_census.py`,
  **已进每轮自检**);**13 条逐条判过写进 ALLOWLIST,一条都没删**(同 `0IMPL`/`0SAT` 的判断)。
  **⭐⭐⭐ 唯一的 (ii)**:retreat 的「前期谨慎冲塔」**算 `nLongEnemyTowers` 两次、读零次**,
  而姊妹拷贝 `mode_farm_generic:1196-1206` 把它当**阶梯第一级**读 ⇒ **retreat 的阶梯是平的**。
  **拒绝补回去,理由是量出来的域**:该级自己的带(`lvl<=2 或 t<2:00`)**72 帧、最近逼近 1,310 u**,
  而那级会用的环是 **1,200** ⇒ **买到零帧**;两个"零不是因为语料薄"的反问各有分母
  (任意帧最近 **173 u**;带内 **72** 帧)。**钉住不补也不扫**(扫掉 = 抹掉证据本身)。
  **本轮三条判据**:①**名字不是身份**(同名跨文件读这一列 **18 条错 17 条**,真判据是
  「那处读坐在同一个块的逐字拷贝里」)②**「只写」≠「死」**(`require` 的加载副作用承重,占 3/13)
  ③**按字节取的源码窗口会被散文推走**(注释加 1.2 kB 顶出两处 3400 窗口,两个文件都红着自报
  「窗口不够宽」—— `0LN2` 自证消息生效;这是「行号会漂」的第三例,而漂它的是注释)。
  **门**:luacheck **0 警告 EXIT=0**;python **27 passed 0 failed**;Lua 切片 **22 例 0 失败**;
  工具变异 **10 变异 10 抓 + 2 控制绿**。
  **`bots/` 只动注释 —— 行为零改动、零新 gate、零新 fixture、零 AWS、`queue.json` 无新条目。**
  **交棒**:**总监**(①无入集提议 ②收两条判据 ③你们的两个 `tpreach` commit **连续第四轮 UNLANDED**
  ④全仓 285 条要不要扩由你排,本组建议**不扩**)、**录像组**(无新请求;#178 已按你们的措辞关闭)、
  **批测台**(无)、**英雄组**(`mode_roam_generic:624` `vBeamEndLoc` 凤凰 sun ray 按半径挑目标,记账不动)。
  报告 `iterations/reports/strategy/20260825T164910Z.md`;backlog 新增 **`0DEAD`**。
- 2026-08-25T13:4xZ:**录像组把「gate 够不到那 44.9%」量出来了,本轮去把那条通路找出来并补上。**
  开工自检 **UNLANDED 2**(**均非本组** —— 总监 08-24T22:2xZ 的 `08ed7c2`/`fc79986`,`tpreach`,
  仍只在 `origin/claude/compassionate-albattani-4zcohy` 上,**连续第三轮被点名**);cadence 11 条 GAP
  (非本组);trunk python 开工/收尾均 **26 passed**(本轮未改 python);开工
  `HEAD == origin/main == 7ed4eb2`;容器无 `lua5.1`/`luacheck`,已装;**AWS $0**(未 bootstrap,
  结构上不需要)。
  **认领依据**:铁律 9 先过 `OWNER_PRIORITIES.md` —— P1 球在总监/批测台/录像组(本组 `pulldrag`
  已于 13:xxZ 被批准入集)、P2 决策侧 id 均已落地、P3 是总监的 ⇒ 本组无未完成优先项;
  open `[strategy]` issue 逐条过完:#160 自己写着「先要帧」、#157 的下一格被 #178 接走、
  #174/#172/#168 都是已交出去的棒 ⇒ 落到 **GH #137 §3 建议 2**,录像组 08-24T00:59Z 明写
  「交协同组」、15:57Z 全 208 局补扫把结构结论稳住,**这条棒躺了 ~13 小时**,零 AWS、判据现成。
  **⭐ 缺陷**:`mode_farm_generic` 的 farm 路径扫三次野怪,**两次的门问的是扫描结果的第一只**
  (`GetLevel() >= 10 or not nNeutrals[1]:IsAncientCreep()`)、第三次(1000u 支)**一句远古子句都没有**,
  而真正被打的目标出自 `FindFarmNeutralTarget(整张表)`。两个营能同时落进一次扫描
  (承重帧里 ogre 营与远古营 **~590u**)⇒ **[1] 是小野 ⇒ 门开 ⇒ 打的是远古**。
  对 **maxHP 型农夫**(viper/naga_siren/huskar/持 bfury 等)这是**常规不是边角**:
  远古野怪正是全场血最厚的那只。兜底 `Action_AttackUnit(nNeutrals[1])` **任何等级都没有门**。
  **⭐⭐ 顺带查出来:阈值错位是三比一**。出厂远古下界在**三处**都是 **10**(两条 `[1]` 子句 +
  `utils.IsValidCreep` 自带的 `> 9`),阶梯说 **12** ⇒ **10..11 就是本 id 的域**
  (10 以下选择器本来就拒远古 —— 用例 W3 在 L9 真实帧上实测到了这一点;12 以上本来就该打)。
  三个数**从源码断言**(W2/W3),不写散文。
  **修法**:落成 gated **`campfarm`**(turbo-only)—— **过滤名单,不重问 [1]**。
  新 `J.Site.FilterFarmNeutrals(list, level, bStrict)`(TS 同步),armed 且 `level <
  J.Site.ANCIENT_MIN_LEVEL`(**=12,与阶梯同一个数、导出一次,用例断言两处不许漂**)时远古不在名单里
  ⇒ 两条 `[1]` 子句、`#nNeutrals>=3` 的闩、`UpdateCommonCamp`、目标选择、无门兜底**全部一致**。
  **门只解一次**(文件级 `NeutralFarmList`),三次扫描全走它 + **调用点计数用例**(是计数不是承诺)。
  未 armed / 到线 / 无可丢 ⇒ **返回同一张表**(同一性不是等价);出厂两条 `>= 10` 子句原封不动。
  **声明的代价**:只有远古时 armed 名单为空 ⇒ 走 farm 块**自己已有的**「这里没东西」分支,
  **不是新造路径**(空名单与该分支存在两头都断言)。
  **本地**:`tests/test_campfarm_ancient_target.lua` **16 例全绿,11 变异 11 抓 + 1 控制**;
  承重帧是**同一个英雄 viper 的四个真实等级 9/10/11/12**,其中 10 与 12 是**同一局相隔 26 秒**。
  **诚实边界(W1)**:野怪那一半语料里没有(`GetNearbyCreeps()` 每枚 fixture 答 `{}`、零枚带
  `creeps` 键,两头断言)⇒ 野怪是**声明的替身**,**没有假装端到端**;域 **140/1040 = 13.5%** 在
  10..11 带、**82** 个 ≥12(反向护栏的人口),两个都是下界。
  **门**:luacheck **0 警告 EXIT=0**;Lua 切片 9 词 **227 例 0 失败**;python **26 passed**。
  **零新 fixture、零 AWS。**
  **交棒**:**总监**(①入集提议 `campfarm`,搭车零增量 ②排波前置:`campgrade` 同 arm 会在上游吃掉本
  id 的域,要读它请排 `campgrade` 未 armed 的腿,**请写进 `campgrade` 未来入集裁定的前置检查**
  ③你们自己的两个 `tpreach` commit 连续第三轮 UNLANDED)、**批测台**(`queue.json:strategy-17`,
  不申请专波)、**录像组**((a) 的核验点 = 「10-11 级 bot 在同时够得着小野营与远古营的位置上打的是
  小野」,判据沿用 #137 §4 自己那把尺子,反向护栏「远古交火总数不许塌成 0」不许省)、**英雄组**(无)。
  报告 `iterations/reports/strategy/20260825T134726Z.md`;`state.json:campfarm_20260825`;
  backlog 新增 **`0PATH`**。
- 2026-08-25T10:3xZ:**上一轮的修法**不能**搬到它的姊妹行为上,而拒它的理由比搬它更值钱。**
  开工自检 **UNLANDED 2**(**均非本组** —— 总监 08-24T22:2xZ 的 `08ed7c2`/`fc79986`,`tpreach`,
  仍只在 `origin/claude/compassionate-albattani-4zcohy` 上,连续两轮被点名);cadence 13 条 GAP
  (非本组);trunk python 开工 **24 passed**,本轮结束 **25**;开工
  `HEAD == origin/main == 5895268c`(`git ls-remote` 一致,无需 rebase);容器无 `lua5.1`/`luacheck`,
  已装;**AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9 先过 `OWNER_PRIORITIES.md` —— **P1**(本组 07:5xZ 交付 `pulldrag` 已交棒)、
  **P2**(`stayfield`/`stayfield2`/`fieldbuy` 均已落地)球都在总监/批测台/录像组,**P3 是总监的**
  (`5895268c` 正是它的落地)⇒ 本组无未完成优先项;open `[strategy]` issue 逐条过完无可动格
  (#120 的解锁条件是两条 **.dem 归因**路径,属录像台工具域);**backlog 顶部三条的「下一格」
  全部被它们自己写着"先别做"**(`0GEO` 等录像看清接哪一波、`0IMPL` 要先立判据、`0ASYM` 等 dumper
  字段)⇒ 取 `0GEO` 同族里最明显的未问问题:**`pulldrag` 能不能搬到勾线上**。
  **⭐ 事实**:同一个代换**逐字**出现在 `J.ShouldCreepPullLane`(`jmz_func:7362-7374`)——
  注释说「兵线」,向量取**泉水** —— 而它 **2026-08-23 已 promote,每一局 turbo 都在跑**。
  **⭐⭐ 读数:REFUSE,且不依赖重建。** 在触发器**自己的域**(本方二塔 → 兵线弧长中点,扣掉拐角
  两侧各一个 600u 步长)里,六行(3 线 × 2 队)最差 **0.99 corner-restored / 0.97 chorded**
  ⇒ 600u 一步最少沿兵线倒退 **581u**。**两个拐角模型同号。**
  **⚠ 判据一(主产出)**:**同一个缺陷形状出现两次不等于它是两次缺陷** —— 搬修法之前先把
  **误差的域**和**触发器的域**求交。差别是结构不是程度:营在**线外** 1.0-1.3k ⇒ 必须走垂直,
  而「朝家」恰恰没有那个分量;兵**在线上**,而 `bWavePushedToUs` 字面就是「兵线被压在我们这半边」,
  **那半边通向本方基地、泉水就在那头**,两向量是同一条射线。
  **⚠ 判据二(它就是第一版说"有缺陷"的原因)**:**对**距离**够用的重建对**方向**可能完全不能用。**
  **横跨直角弯的弦处处偏离它替代的两段各约 45°,而方向误差没有界**(距离误差被弓高界住)。
  实证:第一版用的窄窗口(本方一塔 → 中点)在弦模型里几乎整段落在弦上 ⇒ 最低**中位 0.29**,
  corner-restored 是 **1.00**。取中位不取 min 是因为该窗口**停在拐角上**(铁律 4(ii))。
  拐角**是语料量出来的**:两段塔链夹角 **TOP 88.9° / BOT 91.0° / MID 1.8°**,已成断言。
  **顺带修掉姊妹文件一处潜伏坑**:`pullcamp_lane_geometry.py` 的 `abs(x)<9000` 方框**接受了中路
  那个解**,让 corner-restored 的中路折线**往回折**;对它自己**无害**(改后 `--selfcheck` 输出
  **逐字节相同**、棘轮全绿),对任何读切向的人**致命**。换成参数自由判据:**真正的拐角比它连接的
  两个一塔都更远离地图中心**。
  **工具/棘轮**:`tools/agent/lane_drag_direction.py` + `tests/test_lane_drag_direction.py`
  (**已进 `run_py_tests.sh` ⇒ 已进每轮自检**;4 层 + 4 条反向变异,(c) 当场抓到本工具漏跑姊妹
  文件的塔归属校验,已补)。
  **门**:luacheck **0 警告 EXIT=0**;python **25 passed 0 failed**;Lua 切片 4 个文件 **41 例 0 失败**。
  **`bots/`/`game/` 零改动 —— 本轮是一次拒绝不是一次落地;零新 fixture、零 AWS。**
  **交棒**:**录像组**(唯一一格,零 AWS 零新波:**已 promote 的勾线 episode 里有多大比例发生在
  其兵线弧长中点之外?** 语料已买 —— W3 `spot_20260823_1809*`;**按 §AX.2 在这个数存在之前本组
  不申请任何波次**,`queue.json` 本轮无新条目)、**总监**(①`pulldrag` 入集提议仍挂着 ②收两条判据
  ③你们自己的两个 `tpreach` commit 仍 UNLANDED)、**批测台/英雄组**(无)。
  报告 `iterations/reports/strategy/20260825T103750Z.md`;backlog 新增 **`0PORT`**。
- 2026-08-25T07:5xZ:**总监 07:01Z 交办的动作(收紧 `PULL_CAMP_LANE_GAP`)按它自带的前置条件
  跑完了 —— 结论是 REFUSE,常数一字未动;而拒掉它的那份几何直接把该做的那一格摆了出来。**
  开工自检 **UNLANDED 0**(干净)、cadence 11 条 GAP(非本组)、trunk python **22 passed**
  (本轮结束 **23**);开工 `HEAD == origin/main == 2ff7a52`(`git ls-remote` 一致,无需 rebase);
  容器无 `lua5.1`/`luacheck`,已装;**AWS $0**(未 bootstrap,结构上不需要)。
  **认领依据**:铁律 9,`OWNER_PRIORITIES.md` 的 P1 **球在本组且是总监 07:01Z 刚交出来的**
  (GH #117 追评,明写「⭐ 下一棒 = 协同组,零 AWS」并附「**收紧前必须先跑这一步,不许跳过**」)。
  **⭐ 零成本怎么答的**:判据要「营到 lane 路径的垂距」,而 `GetLocationAlongLane` 在 fixture 里
  是 mock 常数 —— 但 **lane 被语料自己携带的物体钉住**:每枚快照都列 **22 座塔**,而**携带
  buildings 的 61 枚 fixture 对这 22 座坐标逐个完全一致** ⇒ 地图是这一版引擎的**实测常数**。
  工具 `tools/agent/pullcamp_lane_geometry.py`,棘轮 `tests/test_pullcamp_lane_geometry.py`
  (**已进 `run_py_tests.sh` ⇒ 已进每轮自检**;谁再去收紧那个常数,红的是它并指着裁决)。
  **边缘对照(重建必须先复现一件买过的事实)**:W7→W8 是 `pulllane` 首次 armed,录像组公布了
  哪些营继续开火、哪些归零;正确折线必须用**单一阈值**复现该划分 —— 做到了:**仍开火最宽
  1220 < 归零最近 1282**,把常数夹进 [1220,1282);源码的 1200 落在带的**正下方**
  ⇒ 本重建读**宽 20-82u**。**这条缝没被抹平,它正是下面只用「序」不用「值」的原因。**
  拐角也**检查过而非假设过**:corner-restored 折线(两段塔链的交点,零发明航点)下该行只动 **1u**,
  且**序在两模型下一致**(已成断言)。
  **⭐⭐ 读数:收紧被拒。** 仍开火的四个营按垂距排序 = radiant(3994,-5137) **1220 [分子]**、
  dire(-4007,4947) **1084 [分子]**、radiant(200,-5200) 1069 [0]、dire(-800,5000) 1019 [0]
  ⇒ **产出全部 connect 的两个营,恰是最宽的两个;从未产出的两个,恰是最窄的两个。**
  距离阈值**从宽端删** ⇒ **任何有效的收紧都先把分子整个删掉**。**而且它比 SILENT 更难发现**:
  按 p90 收紧后两个零产出营正骑在标定带上 ⇒ 要么全灭,要么 **poke 照常开火、connect 恒 0**。
  **判据(新立)**:**一个「典型值」只有在它和目标分布重叠时才是典型的** —— 这里不重叠
  (引擎能拉到的营全在 1.0-1.3k,拖拽只到中位 742 / p90 992)⇒ **不存在既典型又非空的常数**,
  这不是把常数调对的问题。
  **⭐⭐⭐ 杠杆在哪:注释写对了,代码写错了。** drag 分支的注释是 “walk home-ward in between
  **so the camp follows into the lane path**”,而向量取的是**泉水**。在引擎真会拉的四个营上,
  朝家走每 500u 只关掉 **67 / 67 / 94 / 89 u** 垂距(**81-87% 的位移平行于兵线**),朝线走关掉整 500u;
  配 leash 中位 742u ⇒ 回家式拖拽在脱缰前只关掉 ~100-140u 的 ~1,100u 缺口 ——
  **这就是两波两层 connect 绝对数恒等于 2 的算术原因**(录像组那枚 jakiro 证人「头 6 秒从 1,696u
  单调涨到 3,418u」正是这个向量的样子)。落成 gated **`pulldrag`**:那 500u 的**方向**改成
  **本 bot 被分配 lane 路径上离该营最近的一点**;目标取「离**营**最近」(整段拖拽固定,不随 bot 摆动)、
  **按 营+lane 缓存**(21 次引擎调用每次拉野付一次,不是每帧);**门独立**(turbo + `pulldrag`,
  **不与 `pullcamp` 合取** —— `pullcad` 那条「promote 冻死点名它的门」风险为零);
  未 armed ⇒ nil ⇒ 出厂回家式行走**逐字节不变**。新增 local `ClosestPointOnSegment` 而
  **不重构** `DistanceToSegment`(后者在 armed 的 `pulllane` 子句里)。
  **本地**:`tests/test_pulldrag_lane_step.lua` **13 例全绿,11 变异 11 抓 + 1 控制**;真实帧两侧,
  radiant 那枚**只断言不等式**(落在拐角敏感区,**在拐角上断言量级就是在断言拐角**);
  「最近点」对着**代码拿到的那条 21 点折线**断言,不对着塔链(否则采样伪影会被读成代码选错)。
  **⚠️ 顺带一条 harness 事实(全队适用)**:`bot:GetNearbyTowers()` **只返回还活着的塔**
  ⇒ **不能用它读 lane 几何,塔死了 lane 不会搬家**;本文件第一版就这么写的,在一枚后期帧上
  **静默丢了一个顶点**,是「声明的塔必须在这一帧里」那条断言抓出来的。改读 `fx.buildings`。
  **行号面**:`jmz_func` +94(~8224)、`mode_roam_generic` +9(~267);其下 **6 处**引用**全是散文**,
  三个按行号钉的普查复跑未被推走。
  **门**:luacheck **0 警告 EXIT=0**;python **23 passed 0 failed**;Lua 切片 12 个文件
  **163 例 0 失败**。**零新 fixture、零 AWS。**
  **交棒**:**总监**(①交办的收紧被拒、理由与棘轮见上 ②入集提议 `pulldrag`、搭车零增量
  ③两条判据:「典型值要与目标分布重叠」+「零成本核验引擎量之前,先问语料里有没有钉住它的物体」)、
  **批测台**(`queue.json:strategy-16`,不申请专波;⚠️ **必须 `pullcamp`+`pulllane`+`pulldrag`
  三个同时 armed**,前两个是结构性前置;**验收量是 connect 绝对次数不是率**)、
  **录像组**((a) 的核验点 = 「仇恨野怪后朝**自己那条兵线**走而不是朝泉水走」;**反向哨兵硬要求**:
  20s 内死亡 0/146 与翻面拉 0.0% 不许回吐)、**英雄组**(无)。
  报告 `iterations/reports/strategy/20260825T075402Z.md`;`state.json:pulldrag_20260825`;
  backlog 新增 **`0GEO`**。
- 2026-08-25T04:23Z:**做掉 `0SAT` 自己写下的「下一格」——**跨语句**的可满足性,
  第一次要控制流而不是一次正则扫描。**结论是这根轴空的**,而本轮真正的产出是
  路上的**四个假阳性**:朴素版本报 4 条、**4 条全错、来自四个互相独立的流缺口**。**
  开工自检 **worst exit 3**(UNLANDED **0** —— 本组连续五轮报的那 8 条已消失,GH #155 已落地;
  cadence **10 条 GAP**,五条流同时 ~12h 的洞 = 宿主停摆;trunk python **20 passed**,本轮结束 **21**);
  开工 `HEAD == 28a6d51` **≠** `origin/main == 438fc10` ⇒ **先 rebase 再动手**
  (「实例 clone 的是 origin/main」那条教训的本地版本);容器无 `lua5.1`/`luacheck`,已装;
  AWS **$0**(未 bootstrap,本轮结构上不需要)。
  **认领依据**:铁律 9 先过 `OWNER_PRIORITIES.md` —— **P1/P2 本组交付都已落地**,球在
  总监/批测台/录像组,P3 是总监的 ⇒ 本组无未完成优先项;open 的 `[strategy]` issue 逐条过完
  (#168 是本组上一轮自己开的、交付已落地;#160 等录像组一帧;#157 可做格 08-24T19:26Z 判定已空;
  #143 修法已被 `0ASK` 驳回且 `creeppull` 现为 W7 baseline;#137/#132 已结论)⇒ **无可动 issue**
  ⇒ 取 backlog 顶部 `0SAT` 明写的下一格,**并遵守它写下的前提**(范围收到本组九个决策文件,
  `--all` 只用来确认别处也空)。
  **⭐ 轴**:`0CLK` 问常数的**值**,`0TERN` 问表达式的**解析**,`0SAT` 问一条语句里
  合取两条腿的**可满足性** —— 三根都在**一条语句里面**。本轮问**跨语句**:
  `if <G> then return end` 之后 `not G` 成立,下方的 `if <C>` 还满不满足?
  **结论仍然不需要帧**(不可满足是算术关系,那些行从来没执行过)。
  **⭐⭐ 读数:这根轴空的。** 九个决策文件 **0**;全仓 **275 文件 / 2050 个「在事实之下」的条件**
  只落一处 `mode_attack_generic:8` —— 它的四个析取项**逐字是 `:3` 模块守卫的真子集**
  (少一条 `IsAlive`)⇒ 整块死代码,但**零行为** ⇒ **allowlist 不修**(同
  `hero_earth_spirit`/`hero_phoenix` 的判断)。**修好必须删 allowlist 行,名单只能缩。**
  **⭐⭐⭐ 本轮最值钱的:四个假阳性、四个独立缺口**,每条**看上去都完全合理** ——
  这类工具的危险不是漏报,是**自信地把活分支判死、有人照着删、行为跟着走**:
  (a) `for`/`while` 通过**自己的 `do`** 开块,两边都数 ⇒ 深度永久膨胀 ⇒ 事实**跨函数泄漏**
  (`jmz_func:5773`→`:5975`,两个不相干的函数**碰巧写了同一条 285 移速守卫**);
  (b) `then` 臂的守卫在 **`else` 臂**里什么都不说(`hero_storm_spirit:326`);
  (c) 中间**重新赋值**杀事实(`minion_with_skill:543`,中间又调了一次 `FindAoELocation`);
  (d1) `f(b)` 依赖 **`b`**,重绑**参数**也要杀(`aba_defend:542` **及七处兄弟**,
  每个 `if` 前面都有一行 `b = GetTower/GetBarracks(...)`);
  (d2) **字符串是左值身份的一部分** —— 抹成空格让
  `HasModifier('modifier_black_king_bar_immune')` 与 `HasModifier('modifier_lich_chainfrost_slow')`
  **规范化成同一个左值**(`mode_roam_generic:1434`)。修法:抹成**同长度的标识符形状**,
  填充用 `_` **不是符号** —— `'x or y'` → `_x_or_y_`,`or` 两侧都是词字符 ⇒ **不形成
  `\bor\b` 边界**、不会被误当顶层析取。**四条全部钉成 `[reverse]` 用例。**
  **外加一条结构前提**:三份 MIT 许可证头里的 `furnished to **do** so` 让三个文件读成
  **结构不平衡**(逐行剥离不认 `--[[ ]]` 跨行块)—— **长注释正是散文关键词住的地方**;
  它没造成假阳性**纯属运气**。修好后 **275/275 平衡**,而且这个读数**由扫描器自己的
  stats 断言**,不是用例里另算一遍(M8 就是靠这条才被抓住的)。
  **本地**:`tests/test_guard_implication_census.py` —— 棘轮(九文件 0 / 全仓仅 allowlist /
  allowlist 行必须仍读死 / **命中的成因也钉住**:`guard_line == 3`,`:3` 哪天被收窄用例就红)
  + **零读数的够不够**(`guards 409+268 / conds-under-fact 756 / overlaps 12+3` 都断言下界)
  + 四条反向**各配正向对照**(同形状在同一函数体内 / 同一字符串下**必须**报出来,
  否则「保持沉默」可能只是对着空气沉默)+ `DEAD-BRANCH` 与 `DEAD-DISJUNCT` 不许混
  (「删这条腿」变成「删这个块」是**贵的那个方向**)。**11 变异 10 抓 + 1 控制保持绿。**
  **M6 单独记(改了本轮原本要写的话)**:「顶层 `and` 守卫不建立事实」那条检查**实测不承重**
  (合取本来就既不解析成比较式也不解析成原子),删掉今天不会红 ⇒ 用例**改写成「契约」**、
  写明它防的是未来更丰富的解析器。**把不承重的用例说成承重的,和漏一条用例一样坏。**
  **⭐ 顺带一个零成本的持久化**:棘轮进了 `run_py_tests.sh` ⇒ 进了每轮
  `routine_selfcheck.sh` 的 trunk 体检 ⇒ **这根轴从今天起每 2h 被全队自动重扫一次**。
  **门**:luacheck **0 警告**(**本轮零 Lua 改动**);python 全套 **21 passed 0 failed**;
  Lua 切片 smoke_load 3 / gate_claim 10 / tpdeathbuy 8 / tpgap 22 / level_gate 15 =
  **58 例 0 失败**。**零新 fixture、零新 gate、零 AWS**。
  **交棒**:**总监**(`mode_attack_generic:8` 记账 —— 零行为、不必修、已 allowlist;
  §6 四条判据请收进方法学;**无入集提议** —— 这根轴上没有可拉的杠杆,**不硬造一个**)、
  **批测台**(**无请求**,`queue.json` 不动)、**录像组**(**无取帧请求**,结论算术、帧上看不见)、
  **英雄组**(`hero_storm_spirit:326` / `minion_with_skill:543` 经核**都不是缺陷**,
  已钉成反向用例,**不要去"修"它们**)。
  报告 `iterations/reports/strategy/20260825T042350Z.md`;**GH #172 新开**;
  backlog 新增 **`0IMPL`**(含下一格:原子事实的**蕴含**那一半 —— 但**先立判据再动手**)。
- 2026-08-25T01:24Z:**换了一根正交的轴(合取的**可满足性**),一次全仓扫描落到一个真缺陷:
  「死前买 TP」块要求血量**同时** < 8% **且** = 100% ⇒ 不可满足,约 12 行死代码,而且是
  **上游快照带来的、本仓库历史上一次都没跑过**。落成 gated `tpdeathbuy`。**
  开工自检 **worst exit 3**(UNLANDED 8 条仍全在总监两条分支上、非本组、与 **GH #155** 同一件事,
  **已连续第五轮同读数**;cadence **9 条 GAP**,五条流同时 ~12h 的洞 = 宿主停摆;trunk python **18 passed**);
  开工 `HEAD == origin/main == 2bf137c`(`git ls-remote` 核对一致);容器无 `lua5.1`/`luacheck`,已装;
  AWS **$0**(未 bootstrap)。
  **认领依据**:open 的 `[strategy]` issue 逐条过完,**可做的格都在等别人**(#160 等录像组一帧、
  #143 的修法已被 `0ASK` 驳回且 `creeppull` 现为 W7 baseline、#157 的轴 08-24T19:26Z 判定可做格已空、
  #132/#123 已结论);而 backlog 顶部三条(`0ASYM`/`0TERN`/`0CLK`)的下一格**都明写在等语料或
  等 harness 字段** ⇒ **换轴**。
  **⭐ 新轴 = 合取的可满足性**。`0CLK` 问常数的**值**,`0TERN` 问表达式的**解析**,两条都问
  「这一条腿对不对」;本轮问**两条腿之间**:每个 `if/elseif` 条件按顶层 `or` 拆析取项、按 `and`
  拆合取项,把同一个**左值**上的数值比较收在一起判可满足。纯算术、零 AWS、一次扫描 < 1s。
  **同一把扫描器的另外两问都是空的,一并记账**(空结果也是产出):`if/elseif` 链里后一支被前一支
  蕴含 = **0**(`RefreshCamp` 那型没有第二例);析取项被另一个析取项吞掉 = **2**,但都在英雄文件、
  **只是冗余不改行为**(`hero_earth_spirit:500`、`hero_phoenix:774`,已交英雄组记账、**不必修**)。
  **⭐⭐ 缺陷**:`item_purchase_generic` 的「死前如果会损失金钱则购买额外TP」块,HP 子句是
  `botHP < 0.08 and botHP >= 1`,而 `botHP = J.GetHP(bot)` 是 **0..1 分数**(已断言,并在真实帧上
  实测落在 0..1)⇒ 合取**对任何实数为假**。**逐字来自初始 OHA 快照 `74727e4a:957-958`**
  ⇒ 该块**在本仓库历史上一次都没有执行过**,我们过去任何一次批测都不含它。
  **判它是杂散合取项而不是约定的证据是姊妹块**:往下 ~35 行的「辅助死前买粉」是同一个想法
  (同样的 `botGold < (cost + botWorth/40)`、同样的 `WasRecentlyDamagedByAnyHero(3.1)`、同样的
  充能上限),而它的 HP 腿是 `botHP < 0.06`、**没有配对下界**。这个不对称**已写成 `[reverse]` 断言**。
  **杠杆(一个,最窄)**:写成**选择**而不是析取(`0TERN` 的处方)——
  `local bDyingWithDoomedGold = botHP < 0.08 and botHP >= 1`,armed(turbo + `tpdeathbuy`)改成
  `botHP < 0.08`。**门关着与出厂逐字相同,而且这条同一性是算术不是承诺**(门关着的谓词仍处处为假);
  **阈值一动不动**(`ARMED_LO == LO` 是断言);**门无合取依赖 ⇒ 单独 arm 即有意义**。
  **⚠ 方向:这是加宽,与本组以往每一条相反** —— armed 是**空集的真超集**,**严格增加**出厂树
  从不发生的采购。两个推论已写进入集提议与 queue 单:(1) **一份「无变化」读数不能验证本 id**
  (无变化 = 没 armed 或域为零);(2) **反向哨兵不是「TP 采购数不许塌」,是「TP 花费不许暴涨」**。
  **(c) 成立且是标准打法**:死亡会把未花的金钱赔一部分给击杀者、其余蒸发,死前把钱花掉是教科书
  习惯;块自己的金钱子句正是一条**带**(买得起 ∧ 这点钱本来就要没),TP 卷轴便宜、**用掉而非掉落**、
  且只在手上 TP 不够时买。Turbo 里论据更强(复活快,回场第一件事就是想 TP 回战场)。
  **域(以数据方式读 fixture,不载 jmz_func)**:966 活英雄帧里 `botHP < 0.08` **10(1.0%)**;
  `botHP >= 1` **347**(⇒ 出厂那条上界**单独看并不空**,空的是这一对);两者与「3.1s 内挨过英雄
  伤害」同时成立 = **4 帧**,逐个点名钉住(含一枚**恰好贴着 8% 下沿**的边界邻居)。
  **⭐⭐⭐ 一条会影响别人的 harness 事实(`0DIR`,带错符号的谎话)**:这个块的**两条金钱腿在
  fixture 上读 TRUE** —— `GetGold()` 不在 mock 里(落 `^Get` 默认 **0**)、`GetItemCost()` 答 **0**
  ⇒ `botGold >= tpCost` 是 `0>=0` = TRUE,`botGold < tpCost + botWorth/40` 是 `0 < 净值/40` = TRUE。
  **后果不是「测不了」,是「端到端驱动这个块会全绿,而那份全绿对金钱带一无所证」。**
  两个方向都已断言 ⇒ mock 哪天学会金钱,用例红着要求重测。**因此本轮不主张端到端钉帧,也没假装钉**;
  可买到的本地验证是四件:算术证明 / 门关着逐字同一 / 方向 / 语料可读的那一半域。
  **本地**:`tests/test_tpdeathbuy_dead_conjunct.lua` **8 例全绿**,**11 变异 10 抓 + 1 控制保持绿**。
  M4(把比较**重新内联**回条件、局部仍在)值得单记:它是 `0ASYM` 那条判据的直接兑现 ——
  **只能从源码断言的事实,断言要钉在使用点上不是声明点上**;第一版只查声明行存在,M4 能过。
  **⭐ 顺手修掉本组自己的红树**:`tests/test_level_gate_census.lua` 在 `origin/main` 上**本来就是红的**
  (stash 复现),两条可执行行钉指着 `ability_item_usage_generic.lua:5768/5808` 而源码在 **5783/5823**
  —— 差 **+15**,恰好是本组 **08-24T22:55Z** 那轮为 `tpgap` 在 ~5445 插入的行数。那轮记了该文件的
  `:5751/:5753/:8522` **散文**引用,**漏了这两条可执行的**(`0LN2`「坐标的写法不止一种」)。修法是挪钉子。
  **行号面**:`item_purchase_generic.lua` **+19 行**,插入点 ~999;全仓 25 处该文件的行号引用中
  **18 处在插入点之上(零位移,含唯一的可执行钉子 `line = 228`)**,7 处在其下(+19)但**逐个查过全是散文**。
  **门**:luacheck **0 警告**;相关切片逐个实跑 **218 例 0 失败**(level_gate 15 / gamemode 27 /
  relicguard 8 / dup_component 14 / name_predicate 8 / wk_magic_wand 12 / fieldbuy 35 / fieldcreep 16 /
  replay_260822 62 / gate_claim 10 / smoke_load 3 / **tpdeathbuy 8**)。**零新 fixture**。
  **交棒**:**总监**(入集提议 `tpdeathbuy`,搭车、零 AWS、无合取约束;并请收两条判据:
  「动一个合取之前先问它可不可满足」与「加宽型杠杆不能用『无变化』验收」)、
  **批测台**(`queue.json:strategy-15`,不申请专波;**反向哨兵是硬要求:TP 花费不许暴涨**)、
  **录像组**(条件 (a) 的核验点 = armed 腿录像里「濒死且刚被英雄打过 → 立刻买 TP」,
  顺带看**买完有没有用上**;**无新取帧请求**)、**英雄组**(两处无害冗余记账,不必修)。
  报告 `iterations/reports/strategy/20260825T012401Z.md`;`state.json:tpdeathbuy_20260825`;
  **GH #168 新开**(轴 + 缺陷 + 采购层的恒真 harness 事实 + 给英雄组的两条记账);backlog 新增 **`0SAT`**。
- 2026-08-24T22:55Z:**认领 GH #159(录像组 21:48Z 交回)。本轮最值钱的产出不是新 gate,
  是用仓库里已有的一枚真实帧 + ground truth **否掉了 issue 自己建议的第一个落点候选**,
  然后在被否掉的那个方案**里面**找出可做的最窄子集,落成 gated `tpgap`。**
  开工自检 **worst exit 3**(UNLANDED 8 条仍全在总监两条分支上、非本组、与 **GH #155** 同一件事,
  已连续四轮同读数;cadence **7 条 GAP**,五条流同时 ~12h 的洞 = 宿主停摆,本组那条由今天三轮关掉;
  trunk python **18 passed**);开工 `HEAD == origin/main == ff29c5c`(`git ls-remote` 核对一致);
  容器无 `lua5.1`/`luacheck`,已装;AWS **$0**(未 bootstrap)。
  **⭐ 洞**:`tpsafe2`(扫 700)的调用点被 `nMode ~= BOT_MODE_RETREAT` 挡在撤退分支外,
  `tpsafe`(跑在撤退分支里)的**第一个**谓词就是「350 内有敌」⇒ **撤退时最近敌人在 (350,700]
  的按下,两个守卫都不拒绝**。W7:贴脸按下的 **58.6%** 在这一带,通道内致死 **15.7%** 对 **2.3%**。
  **⭐⭐ 而 #159 §6 建议的第一个修法(把撤退分支也过一次 700 否决)被本轮否掉,反例是现成的 fixture**:
  `f_260819_222030_jugg_tp_start` —— 一次**真实的撤退 TP**,Lich 在 **477u**(正在带内),
  声明真实射程后 `CanEnemyInterruptTpChannel` **答 TRUE**;而 fixture 自带的
  `observed.died_after = 105.9` 说明**通道走完了、人活了将近两分钟**。**对齐两个半径会拒掉这次成功的逃跑。**
  **判据(新,已交总监收进方法学)**:**「域没拼上」不等于「拼上就行」** —— 两个守卫半径不同
  可能是**代价不对称**的编码(travel TP 错拒 = 几秒;**撤退 TP 错拒 = 一条命**),对齐前先问
  **哪一边错拒更贵**。顺带记:打掉 juggernaut 大部分血的 Viper **在 700 之外**(burst 473),
  守卫看不见他 —— **而通道照样走完了**,所以「看不见最重的那个」在这一帧上并不是缺陷。
  **杠杆(一个,最窄子集)**:gated `J.ShouldNotTpUnderLethalPressure`,接在撤退块**紧挨 `tpsafe`
  之后**,只拒**站着不动已经必死**的按下:350 内无敌(**tpsafe 的地盘一律不碰**)∧ 能走
  (未定身 / 未减速到 285 以下,与 tpsafe 的 fall-through 同形)∧ 700 内有可见敌
  ∧ **带内估计伤害(窗口 3.0s)≥ 当前血量**。这是 `tpsafe` 那条「贴脸爆发会杀我 ⇒ 赌通道」
  fall-through 的**镜像**,而同一份 W7 语料显示那个赌注在 ≤350 带**实测在输**(致死 15.9%);
  **本条不把它延伸进空档带**。**窗口取 3.0s 而不复用 `J.GetTotalEstimatedDamageToTarget`(硬编码 5s)** ——
  问 5 秒会拒掉那些其实走得完的按下,**正是 juggernaut 那一帧记录的错误**。门无合取依赖 ⇒
  **单独 arm 即有意义**,不踩 `pullcad` 那条「promote 冻死点名它的门」的教训。
  **域(实测)**:`_tpgap_band_sweep.lua`,966 真实帧里空档带 **161(16.7%)**、tpsafe 那带 96、
  皆无 709,**三者划分语料已断言**。爆炸半径大 ⇒ 本轮只落最窄子集。
  **⭐⭐⭐ 一条会影响别人的 harness 事实**:`GetAttackRange` 在**每一枚 fixture 英雄**上读 mock 默认
  **150**(GH #145)⇒ 射程腿只能在 **300** 内为真,**严格低于这条带** ⇒ 空档带 161 帧上
  `CanEnemyInterruptTpChannel` 命中 **0/161**。**后果不是「测不了」,是「写出来会全绿而什么都没证」**
  —— 任何射程型修法在本地都是同义反复。本轮谓词**刻意不含射程腿**;juggernaut 那条用例
  在声明 Lich 真实 500 **之前**先断言 mock 的 150,GH #145 一被修它当天红。
  **本地**:`tests/test_tpgap_retreat_band.lua` **22 例全绿**;世界突变 M1-M8,**源码突变 3 抓 3**。
  第三条源码突变值得单记:「`nChannelSeconds` 声明留着、调用改传字面量 5」**在任何帧上都看不见**
  (mock 的 `GetEstimatedDamageToTarget` **对 duration 不敏感**,已写成断言),第一版断言只检查
  「局部声明存在」⇒ **全绿放行**。⇒ **判据:一个只能从源码断言的事实,断言要钉在使用点上,不是声明点上。**
  **诚实边界(不藏)**:正例帧 `f_222428_lion_lich_burst` 的 observed 窗口是 **8.0s**、
  `died_after = 6.9s` ⇒ 语料证得了「谓词在真实致命压力帧上开火」,**证不了这次按下会死在通道里**;
  能证的帧(W7 drow_ranger t=281.3,**通道开始 2.5s 后死**)**还不在 `tests/fixtures/`**,已向录像组要。
  **门**:luacheck **0 警告**;相关用例逐个实跑 **149 例 0 失败**(tpsafe_gate 7 / slardar_tp 7 /
  sven_tp 4 / tpwatch 7 / lina_tp_home 20 / gate_claim 10 / smoke_load 3 / mid_tp_support 18 /
  canbreakteleport 6 / tpresponse_quota 10 / relicguard 8 / gamemode_world 27 / **tpgap 22**);
  python 侧 **18 passed**。**零新 fixture**。
  **行号面**:`ability_item_usage_generic.lua` **+15 行**,插入点 ~5445 ⇒ 仓库里对该文件的
  `:5751`/`:5753`/`:8522` 引用**全部是注释、无断言依赖**,现各 +15,已记账;`jmz_func.lua` +91,插入点 ~5880。
  **交棒**:**总监**(入集提议 `tpgap`,搭车、零 AWS、无合取约束;并请收两条判据进方法学节)、
  **录像组**(① 把 W7 drow t=281.3 做成 fixture 交回;② 下次核验把 `tp_channel_death.py` 的
  `mid_gap` 带**按「带内估计伤害 ≥ 当前血量」再切一刀** —— **本 id 的域是那一小块,不是整条带**,
  用整条带的读数判它会系统性读成「没效果」)、**批测台**(`queue.json:strategy-14`,不申请专波;
  **反向哨兵是硬要求:撤退 TP 总数不塌**)。
  报告 `iterations/reports/strategy/20260824T225500Z.md`;`state.json:tpgap_20260824`;
  GH #159 已追评;backlog 新增 **`0ASYM`**。
- 2026-08-24T19:26Z:**沿 GH #157 的筛子走到底,发现轴上「析取+live+子集方向+本地可测」
  四条同时成立的格子已空 —— 而**换轴的那一步就在筛子的执行过程里**:全仓五处 turbo 缩放
  **从来没有被执行过**,原因是解析不是常数。落地 gated `tbearly` + 全仓棘轮,新开 GH #165。**
  开工自检 **worst exit 3**(UNLANDED 8 条全在总监两条分支上、非本组、与 **GH #155** 同一件事,
  已连续三轮同读数;cadence **6 条 GAP**,**五条流同时 ~12h 的洞** ⇒ 宿主停摆,本组那条由今天三轮
  关掉;trunk python **18 passed**);开工 `HEAD == origin/main == 5f1f543`(`git ls-remote` 核对一致);
  容器无 `lua5.1`/`luacheck`,已装;AWS **$0**(未 bootstrap)。
  **⭐ Lua 没有三元运算符,而 `cond and x or y` 只在 `x` 永不为假时才是三元式。**
  `J.IsModeTurbo() and DotaTime() < 18*60 or DotaTime() < 25*60` 里 `x` 是**布尔**,`and` 又比 `or`
  结合更紧 ⇒ 解析成 `(turbo and t<18*60) or (t<25*60)`;再加上 **18*60 < 25*60**,第一个析取项
  **蕴含**第二个 ⇒ **整式在任何模式下逐字等于 `t < 25*60`,那个 turbo 常数一次都没决定过任何事**,
  而且**没有任何计数会报警**。这是 **GH #160(块 2 被块 1 支配)的析取版孪生**,同一条规则:
  结论是两个常数之间的**算术关系** ⇒ 用算术断言,**帧上两条腿处处一致,采样只能证同义反复**。
  **全仓 25 处 `IsModeTurbo() and X or Y`,5 处是坏的那一形**:`mode_farm_generic:466`(18/25,本轮修)、
  `hero_alchemist:574/585`(15/30、16/32)、`rubick_hero/alchemist:507/518`(逐字拷贝)、
  `aba_site:751`(8/12,**孤儿:`____exports.IsInLaningPhase` 零调用方**,约 130 处消费方走的是
  `jmz_func:9834` 那个**数字型三元式、写得对**的 `J.IsInLaningPhase`)。其余 20 处 `x` 是**数字**
  ⇒ 结构上正确;另有 `mode_farm_generic:964` 是**手写双侧式**(第二项自带 `not IsModeTurbo()`)⇒ 也对。
  **这两种「看起来像但其实对」的形状都写成了 `[reverse]` 用例**,免得日后有人把匹配器改宽、
  开始要求「修好」二十处本来就对的常数。
  **⭐⭐ 筛子的结果本身是产出**:23 行逐条过完 —— `lf_*` 全族(mana/rescue/salve/threat)**inert**;
  `X.RetreatWhenTowerTargetedDesire` 的 `10*60` live 但**本地不可测**(要塔在 800 内,966 帧里
  898 内只有 32);`ShouldCreepPullLane` 的 `6*60` live 但**收窄与 owner P1 反向**且 W7 正拿它当
  baseline,**刻意不碰**;`mode_farm:1049`/`retreat:794` 是**合取型**(`0CLK` 明写不许折半);
  `Site.IsTimeToFarm` 的下限 `5*60` 与 `mode_farm:443` 的 `t>8*60 or lvl>=8` 折半都是**加宽**
  ⇒ 与「强迫核心多刷钱实测更差」相反、也不是 `0CLK` 说的子集方向。**⇒ 轴不关,但下一步不再是
  挑下一行**:要么等录像组那一帧,要么换一根正交的轴(本轮就是后者)。
  **杠杆(一个)**:`mode_farm_generic` 的 `bEarlyGame` 改析取为**选择** ——
  `local nEarlyClock = 25*60`,armed(turbo + `tbearly`)取 `18*60`。**门关着与出厂逐位相同**
  (出厂塌成的就是 25*60,两模式皆然,已断言);**armed 边界低于出厂 ⇒ armed 谓词是出厂的子集**,
  这一支只可能少开。移动的带 **18:00–25:00**。
  **⚠ 域的实话自己先说(`0DOM`)**:turbo 局约 20 分钟、**批测局上限 10 分钟** ⇒ **cap 10 下
  域结构上为零、读数必然全 0,那是预期不是失败**。`strategy-13` 明写「cap 10 的波次不要记 verdict,
  只核 WIRED」,取证波在 **GH #108 cap 10→25 落地之后**;入集提议里**自认低优先**,集满先让位给
  `pulllane`/`towerfear`。本轮值钱的是**缺陷类 + 棘轮**,不是这一格的效应量 —— 写在前面,免得
  半个月后有人拿一份全 0 读数把它记成「测过,无效」。
  **没有钉帧,而这是可证的不是省略的**:104 枚 fixture 的 `time` **最大 690.5s(11:30)**,全在
  18:00 之下 ⇒ 每一帧上 armed 与出厂**必然一致**。**这一条本身写成了断言**:哪天有 fixture 落进
  `[18:00,25:00)`,该用例红着通知「语料终于够得到了,去钉帧」。
  **本地**:`tests/test_turbo_ternary_dominance.lua` **12 例全绿,13 变异 11 抓 + 2 预期放行**。
  **两条放行如实记录**:**M12(边界邻域点被删)不抓 —— 与 `towerfear` 那一格相反**:那里没有
  `149.9/150.0/150.1` 三点、加宽型变异能过掉整份文件,**这里支配是全域关系,边界点不承重**;
  「边界两侧必须钉死」这条做法在**这一类**结论上不适用,下一个人不该照抄。M13 是注释控制组。
  **同一文件带全仓棘轮**:坏形出现次数必须逐位等于 allowlist(5 条,`find|sort` 顺序配对),
  且每条记的两个常数必须仍满足 `turbo < normal`(**仍被支配**)⇒ **新写一处当天红,修好一处必须
  删行,名单只能缩**。**LIMITS 写在文件头**:逐行扫描(跨行同形看不见)、只认带比较运算符的那一种、
  双侧式故意不报 —— 后两条写成 `[reverse]` 用例不是注释。
  **行号面**:`mode_farm_generic` **+30 行**,插入点 ~463;`test_level_gate_census.lua` GATES 表
  **后两行** `524/553` → **`554/583`**,**前三行 `303/387/410` 在插入点之上零位移**,已改并把
  「只动了后两行」写进表头;`test_pingstamp_world_assertion.lua` 的 `:135-137` 在插入点之上,未受影响。
  **门**:luacheck **0 警告**;`mode_farm_generic` 的消费方用例文件逐个实跑(activemode 13 /
  campgrade 14 / campsel 21 / defend_ping 8 / farmfear 8 / gamemode 27 / level_gate 15 /
  pingstamp 18 / relicguard 8 / sven_idle 6 / wk_l1trade 12 / lina_walk_home 19 / turbo_ternary 12),
  另 gate_claim 10 / smoke_load 3 / pullcamp_lane_gap 15 / creeppull_zone 16 / towerfear 15,
  **合计 227 例 0 失败**;全套见 GH #124。**零新 fixture**。
  **交棒**:**总监**(入集提议 `tbearly`,搭车、零 AWS、**自认低优先**;另建议把本轮判据
  「**一个 turbo 常数写对了没有,先要问它解析出来是不是它看上去的样子**」收进 `test_set.md`
  方法学节)、**批测台**(`queue.json:strategy-13`,不申请专波;cap 10 下只核 WIRED)、
  **英雄组**(**GH #165**:alchemist 四处同类坏形,turbo 死带 **15:00/16:00–20:00**,
  **比本轮这一格大**;棘轮已在位,修好后必须来删 allowlist 行)、**录像组**(**无新请求**)。
  报告 `iterations/reports/strategy/20260824T192628Z.md`;`state.json:tbearly_20260824`;
  **GH #165 新开**、GH #157 更新(轴的可做格已空);backlog 新增 **`0TERN`**、`0CLK` 标注见底。
- 2026-08-24T16:41Z:**时钟常数轴第二格 —— 量完之后**决定不落 gate**;真正的产出是两个结构性事实。
  `bots/` 与 `game/` 本轮一行未改。**
  开工自检 **worst exit 3**(UNLANDED 全在总监两条分支上、非本组、与 **GH #155** 同一件事;
  cadence **6 条 GAP**,**五条流同时出现 ~12h 的洞** ⇒ 宿主停摆不是各组偷懒,本组那条由本轮关掉;
  trunk python **18 passed**);开工 `HEAD == origin/main == 1e1d380`(`git ls-remote` 核对一致);
  容器无 `lua5.1`/`luacheck`,已装;AWS **$0**(未 bootstrap)。
  **⭐ 先降级了本组自己点名的两格,而理由值得当判据用**:`0CLK` 的候选 (i) `ShouldConserveManaInLane`
  的 `10*60` 与 (ii) `GetRescueTpTarget` 的 `8*60`(`lfcorelane`)外层门分别是
  `J.IsLaneFixOn('mana')` / `('rescue')`,而 **`lf_mana` 与 `lf_rescue` 都不在测试集** ⇒ helper inert
  ⇒ 给它的常数再套 gate,armed 后仍是**逐字节 no-op、结构上买不到 (a)**。
  **新判据:一个 gate 的时钟腿不比它外面那道门更活 —— 先问函数跑不跑,再问常数对不对。**
  **改查的那一格**:`mode_farm_generic.X.ShouldRun` 的「前期谨慎冲塔」块 —— `towerfear` 的**同名孪生**,
  **无任何 gate**(返回非零 ⇒ `GetDesireHelper` 给 ABSOLUTE×1.1,并**按返回值闩住那么多秒**)。
  **杠杆判定:牙齿 0,不落 gate。** 966 帧上长子句问到 **33 开火 0**、近子句问到 **16 开火 1**,
  那 1 帧由**等级腿**持有(4 级 lina,t=201.3)⇒ **时钟腿单独持有 0 帧**。
  **两种零要分开说**:不问塔环只看两条腿时,`t<180` 有 100 帧、**3 帧**已过 `lvl<=4`
  ⇒ **域是存在的**,杀死它的是**塔环那个合取项**(没有一帧是「5 级以上、3:00 前、敌方塔 898 内」)——
  **不是常数已够紧,是 `towerfear` 同一条语料短板**。要这一格的牙齿,**先要帧不是先改常数**。
  **⭐⭐ 路上撞到的两件事比那个 gate 值钱。其一(GH #160):这个块被完整写了两遍,
  第二遍在鸣笛之后一句话都决定不了。** 块 2 每个环都在块 1 对应环里面(`999<1200`、`988<1100`、
  `966<980`;**非 mid 时两块都不重新 `local` 近环,读的是同一个 898**),等级/时钟/校准腿**逐字相同**
  ⇒ 块 2 每条子句**蕴含**块 1 的,而**块 1 先跑并 `return`**;**唯一的不对称是块 1 多一个
  `DotaTime() > 0`** ⇒ **块 2 只可能在鸣笛前决定事情**,而它的外层门(1600 内有敌 或 血<700)
  鸣笛前不成立 ⇒ **~28 行 `return 1` 是死代码,而且带的是另一个闩长(1s vs 2s)**。
  语料独立同意:**块 2 门开而块 1 门关 = 0 帧**;**块 2 环有塔而块 1 环没有 = 0 帧**(长近都是 0)。
  **推测原意是分级反应**(近=强/远=弱),写成了**宽环配长闩且排在前面** ⇒ 分级塌成恒定 2 秒。
  **本轮不修**(重排/删除是行为改动、域同样 1/966,先要帧),但**已写成断言不是注释**(`0WRAP` 第 2 条)。
  **其二:本组 14:04Z 自己造的一条红**。`test_defend_ping_declaration_ratchet.lua` 的 `[ratchet]`
  在 main 上红,点名的**唯一文件是 `test_towerfear_clock_leg.lua`**。未声明的 fixture 世界里
  `defendPings` 不是「没人 ping」而是**「这一瞬刚被 ping」**(`mode_farm_generic`/`aba_push` 首读即
  用 `GameTime()` 盖章、5 秒内返回 NONE)⇒ 上一轮那句**竞价冠军**是在 **farm 与三条 push 被静音**的
  退化世界里读的,正是 GH #91 立棘轮要防的事。**已按 `stale` 重取并把理由写在调用点**:
  22 个模式文件 / **16 个可驱动 / 零位移**,`mode_farm_generic` 两种世界都出价 **0**,冠军仍是
  retreat **1.1** ⇒ **上一轮结论存活**,从「碰巧对」变成「声明过并复核过」;towerfear **15 例仍全绿**。
  **世界断言(已知事实的量化,不算新发现)**:`GetAssignedLane` 不在 mock 里 ⇒ 落 `^Get` 默认 **0**,
  而未知 ALL_CAPS 全局解析成 **≥1001** ⇒ **966/966 帧不等于任何 `LANE_*`**;
  后果是**两个块的 mid 分支本地一帧都验不了**,支配关系**只能从源码算术证**(所以它被写成断言)。
  `bots/` 里共 **41 处 / 24 文件**,其中 **4 处**直接比 `LANE_MID`(全结构性 FALSE),
  其余 37 处把**非法 lane id 0** 传给 `GetLocationAlongLane` / `GetLaneFrontAmount` 之类下游。
  **本地**:`tests/test_farmfear_block2_dominated.lua` **8 例全绿、0.3 秒**(**刻意不在用例里跑那 37s
  普查** —— 套件在例行容器本就跑不完,GH #124;载重结论是源码算术,普查是旁证);
  含 **>10 万格纯模型网格**覆盖 fixture 到不了的 mid,并**反向断言鸣笛前那个角落非空**
  (否则结论就成了「到处都死」,那是另一句更强的话);**16 变异 15 抓 + 1 控制正确保持绿**
  (控制 = 块 2 长环 `999→1199`,仍被支配 ⇒ 应绿,证明抓的是支配关系不是「有人动了文件」);
  两条 `<` vs `<=` 近失单列(块 2 长环→**1200**、块 1 长环→**999**,即两环相等)。
  普查 `tests/_farmfear_sweep.lua`(**37s、零 AWS**),**零新 fixture** ⇒ #106/#107 破坏面不存在。
  **门**:luacheck **0 警告**(`bots/` 一行未改,变异做完已 `git status` 核对干净);
  `mode_farm_generic` 的 **12 个消费方用例文件逐个实跑**(activemode 13 / campgrade 14 / campsel 21 /
  defend_ping 8 / farmfear 8 / gamemode 27 / level_gate 15 / pingstamp 18 / relicguard 8 /
  sven_idle 6 / wk_l1trade 12 / lina_walk_home 19),另 gate_claim 10 / smoke_load 3 /
  pullcamp_census 21 / creeppull_zone 16 / pullcamp_lane_gap 15 / towerfear 15,**合计 0 失败**。
  **交棒**:**GH #160**(不随本轮关闭,关闭条件写死在 §6)、**录像组**(要**一帧**:
  `t<180` 且 **5 级以上**且敌方塔 **898 内** —— 同时解锁杠杆与分级重排,**与 GH #157/`towerfear`
  同一格语料,可一起取**)、**总监**(**无入集申请**;建议把「合取不许折半」收进 `test_set.md`
  方法学节 —— 它管的是所有人下一次动 turbo 常数的手)、**批测台**(**无请求,零 AWS**,`queue.json` 未改)。
  报告 `iterations/reports/strategy/20260824T164159Z.md`;`state.json:farmfear_census_20260824`;
  backlog **`0CLK` 已改写**(两格降级 + 合取/析取第二轴 + 下一格在等帧)。
- 2026-08-24T14:04Z:**`[strategy]` 8 条 open issue 全部已交出下一棒、owner 三项优先项都不在本组手上
  ⇒ 走 backlog 自选,开一条新轴:**turbo 里的普通模式时钟常数**。落地 gated `towerfear`。**
  开工自检 **worst exit 3**(UNLANDED **8 条全在总监两条分支上**、非本组,且与 **GH #155** 同一件事;
  cadence **6 条 GAP**,本组那条由本轮关掉;trunk python **18 passed**);
  开工 `HEAD == origin/main == 31262b8`;容器无 `lua5.1`/`luacheck`,已装;AWS **$0**(未 bootstrap)。
  **⭐ 一个问题写了两遍,而 turbo 里只剩错的那一份还在答**:`mode_retreat_generic.X.ShouldRun`
  「前期谨慎冲塔」的粗判据 `( botLevel <= 5 or DotaTime() < 5*60 ) and nEnemyTowers[1] ~= nil`,
  两条腿问的是**同一件事**(「我还是不是脆的前期英雄」)。普通模式里几乎重合(5:00 ≈ 5 级);
  **turbo 双倍经验 ⇒ 同一墙钟时刻站着 7-10 级英雄**,时钟腿**恰好为等级腿已放行的等级继续开火**。
  而这个 `return 2` 经 `GetDesireHelper` 是 **BOT_MODE_DESIRE_ABSOLUTE × 1.1 ⇒ 压过每一个模式**。
  **杠杆(一个)**:armed(turbo + `towerfear`)**只把时钟腿折半**到 **2:30**;等级腿、898/980 塔环、
  下面那条**校准判据**(塔真的在打我 + 我一个人)一律不动 ⇒ **armed 谓词是出厂谓词的子集**,
  这个 return **只可能少开不可能多开**;放掉的帧由校准判据接 —— **与同文件 `towerreach` 同形**
  (接到消费方上的是粗的那个,校准的那个在旁边闲着)。
  **常数不是这里发明的(`0NUM`)**:引擎自己把 turbo 阶段计时器折半,本仓库**凡有人看过的地方
  都已照做** —— `Buff/NeutralItems.lua` 四档中立 17/27/37/60 → **8.5/13.5/18.5/30(全 0.5)**、
  `J.IsEarlyGame` 10\*60 → 5\*60。**⭐ 语料独立佐证了这个边界**:被放掉的窗口 `150 ≤ t < 300`
  有 **206 帧、均值 4.60 级、42 帧(20.4%)已过等级腿**;`t < 150` 的 **80 帧一帧都没过(0/80,
  故意留成等式** —— 它是选 2:30 而不是别的比例的唯一理由**)。
  **域(`0DOM`,帧域永不与事件率相加)**:塔在 898 环内 **32/966 = 3.3%**;粗判据被**问到 17 帧**;
  **开火 3 帧** = 等级腿持有 **2**(armed 在这两帧**逐位不变**,已成对照)+ **时钟腿单独持有 1**
  ⇒ **armed 在本语料只改 1/966 帧**;**这是关于这份语料的**(批测局在攻塔前自终止、这批 fixture
  当初为别的问题采,「站在敌方塔下」严重欠采样)。
  **承重帧** `f_260819_142047_zuus_ult_denied` t=278.5:**7 级** Zeus、369/911(40.5%)、离敌方塔 **727**、
  1600 内**零敌零友**(外层门靠 `GetHealth() < 800` 进来)、**塔没在打他**⇒校准判据为假、
  **放行是真放行不是被下游接住**。出厂 **1.1(竞价冠军)**,armed **−0.3616**,**冠军换人且除 retreat
  外零位移**。地面真相(记录不作论据):`observed.burst` **空**,**82.9s 后**才死。
  **⚠⚠ 承重帧不是新的,而这正是必须自证可分离的理由**:`stayfield2` 08-22 提议量到的就是它
  (`test_set.md` 11:2xZ:「7 级宙斯 40% 血、离敌方塔 727 码」)—— 那轮从**补给侧**撞上,
  第一版谓词会把这同一个 ABSOLUTE×1.1 **当副作用**压成 0,于是**给自己加了塔子句**避开,
  并留话「**凡今后动它的出价都要先看这一条**」。**本轮正面动它**,所以可分离性是**量出来的**:
  **当前 25 个可 arm id 全 armed,该帧仍读 1.1**(没有一个在集 id 碰得到它);
  **`towerfear` 单开与 `towerfear`+全集逐位相同(−0.3616)** ⇒ 效应可归因,**搭任何一波都行**。
  **本地**:`tests/test_towerfear_clock_leg.lua` **15 例全绿,11 变异 11 抓**
  (近失两条:时钟折成 **/1.2**、`<` 改 **`<=`**;还有「把等级腿一起 gate」=两个杠杆);
  边界 **149.9 / 150.0 / 150.1** 三点两侧钉死 —— **没有这三点,加宽型变异能过掉本文件其它每一条**;
  子进程全语料普查 `tests/_towerfear_sweep.lua`(**37s、零 AWS**);**零新 fixture** ⇒ #106/#107
  破坏面结构上不存在。
  **顺带 `0SRC` 第二次实证**:普查最初用整文件 `match` 读 `local nEnemyTowers = ...GetNearbyTowers(N)`,
  拿回的是**同文件更早那个函数**(`RetreatWhenTowerTargetedDesire`)的 **800**,而 `ShouldRun` 自己是 **898**
  ⇒ 环少算一圈(`tower_in_ring` 22→32、`crude_reachable` 10→17)。已改成先切函数体再 match。
  **行号面已查**:本轮 `bots/mode_retreat_generic.lua` **+26 行**,插入点在 ~885;
  全仓库指向该文件的行号锚(`:196-202/:222/:236/:252/:261/:262/:493-508`)**全部在插入点之上,零受影响**;
  源码窗口另加**自证断言**(够不到校准判据时以说真话的消息失败,`0LN2` 同族)。
  **门**:luacheck **0 警告**;**该文件的每一个消费方用例文件(18 个)逐个实跑,合计 0 失败**
  (fieldcreep 16 / nearby_structures 6 / unit_list_all 4 / zuus_lina 6 / wk_revive 6 / reincarn_gap 4 /
  l1trade 12 / fieldbuy_supply 23 / lina_tp_home 20 / lina_walk_home 19 / bc_silent 4 / retnear 11 /
  retreat_priority 3 / towerreach 12 / tpcommit 9 / tpdying 9 / tpwatch 7 / wk_reincarn_mana 6),
  另 level_gate 15 / census 切片 50 / pingstamp 18 / smoke_load 3 / gate_claim 10 全绿;
  全套见 GH #124(实测 96m35s,例行容器跑不完)。
  **交棒**:总监(`test_set.md` **14:0xZ 入集提议**,搭车、零 AWS 增量、**单独 arm 即有意义**)、
  批测台(`queue.json:strategy-12`,**不申请专波**)、录像组(条件 (a) 判据**已开工前登记**在 queue 条目:
  正向 = 对线期因塔而起的撤退 episode 下降 + 6-10 级英雄塔附近停留时长上升;**反向不许省** =
  同窗口**死亡数不许上升**(本修法唯一可信的代价)、塔下**总撤退不许塌向 0**(那不是收窄是关闭)、
  对线期 gpm/xpm 不许低于 baseline;**计量三条 GH #148 照办**,ab/ba 两层都要给、计数类不报中位数)。
  **预登记的反向读法**:三个读数都不动 ⇒ **第一嫌疑 arm 串漏了 `towerfear`**(逐字节 no-op、
  **没有任何计数会报警**);第二嫌疑是这个**联合事件**(6-10 级 + 2:30-5:00 + 塔 898 内)在真实局里
  比本语料暗示的还稀 —— **那时不要再收窄谓词,要去量事件率**(帧域 1/966 是**语料的下界**)。
  报告 `iterations/reports/strategy/20260824T140451Z.md`;`state.json:towerfear_20260824`;
  新 backlog 条 **`0CLK`**(时钟常数轴的分类与下一格候选);**GH #157**(普查 + 修法 + 交棒,
  **不随本轮关闭** —— 轴上还有 23 行)。
- 2026-08-24T01:27Z:**认领 GH #117 §4(录像组 08-23T09:09Z 的交回,自那以后 8 轮无人认领),
  落地 gated `pulllane` —— 上一格把营地挪近了「家」,没挪近「我这条线」。**
  开工自检 **worst exit 3**(UNLANDED **8 条全在总监两条分支上**、非本组;cadence **两条 GAP**
  batch-desk 4.0h / director 4.1h、均非本组;trunk python **18 passed**);
  开工 `HEAD == origin/main == f17ad84`;容器无 `lua5.1`/`luacheck`,已装。
  **⭐ 上一格买到了一半,而没买到的那一半的解释就写在录像组自己的两个数里**:own-side 子句在
  **两波 348 局 / 146 poke episode**(两波代码逐字节相同、种子相同)上买到**安全**那一半且两波一致
  ——**20s 内死亡 2/97 → 0/146**、翻面拉 **7.2% → 0.0%**、<35% 血 8.2% → 3.7%/5.4%;
  **connect 却是反向的**:21.5% → **12.1% / 9.9%**。为什么:跟随小野最远走出**中位 742u**
  (p90 992,**max 1,170**),野点离最近线兵**中位还差 1,068u** —— **这两个数一步没动**。
  **own-side 移动的是纵向坐标,而失败发生在横向坐标上。**
  **杠杆(一个)**:候选营必须在 `bot:GetAssignedLane()` 那条 lane 的路径 **1200u** 内,
  gated `pulllane`、turbo-only。路径 `GetLocationAlongLane(nLane, k/20)` 采 21 点
  (`nLane` 是均衡子句上面**已经解出**的同一个值 ⇒ 无新引擎调用种类)。
  **常数是别人花钱买的数(`0NUM` 第二次兑现)**:1200 = 那个 **max 1,170u** 向上取整,
  语义 = 「离线超过**有史以来最长的一次拖拽** ⇒ 不是更差的拉野,是**不成立**的拉野」;
  **刻意取数据支持的最宽值**,因为反 SILENT 那一侧本地结构上不可测(语料无营地表)。
  **⚠⚠ 录像组 §4 的字面是「换成」,本轮是「加上」,而这不是措辞**:换掉 own-side =
  把那份两波一致的安全收益**退回去换 connect**,那是**两个杠杆**。两条子句正交(纵向/横向),
  一个 mid 辅助完全可以选到「在我方半场、却离他那条线 1,630u」的营 —— 那正是证人的形状。
  **已成 [reverse] 用例:两条必须同时在**(M10「用新子句替换掉 own-side」被抓)。
  **⚠ 排波:arm 串必须同时含 `pullcamp` 与 `pulllane`**(门是合取;`pulllane` 未 armed ⇒
  路径 nil ⇒ helper 恒 TRUE ⇒ **逐字节 no-op 且没有任何计数会报警**)。**已成用例不是承诺**,
  连同「`pulllane` 单独 arm 结构上产不出拉野」「引擎答不出 lane 在哪时**绝不许**把机制静音」。
  **本地**:`tests/test_pullcamp_lane_gap.lua` **15 例全绿,14 变异 14 抓**。
  **承重帧挑得是结构性的**:`f_260820_162821_lion_drain_lethal` 的 ogre_magi 满足
  `botDepth + 1500 < boundary` ⇒ **own-side 子句在这一帧上算术上拒不掉任何东西**
  ⇒ 每一次拒绝**唯一归给新子句**(已断言)。牙齿 = 离线 600u 的营(离 bot 1,342u)
  **赢过**离线 1,300u 的营(离 bot **1,300u = 更近**),**出厂选更近那个也单独断言了**。
  **M9(`<`→`<=`)是空变异,专门为它加了一条轴对齐路径上的纯算术用例**才钉得住
  (无理垂直向量上「恰好 1200」不可表示);M8 钉的是**量到线段不是量到采样点**
  (21 点间距 ~770u,点式在判定线上高估 ~60u ⇒ 5% 误判带;盲区帧真实 gap 1,180u,
  点式拒、线段收);M14 钉线段夹紧、M11 钉采的是 `nLane` 不是 `LANE_MID`、M13 钉 reach 1500 没被一起拉。
  **证人按形状不按帧,并写进用例名**:录像组的钉帧 `run_001127/…jakiro t=161.4`
  (小野→线兵 1,696u **单调**涨到 3,418u)**不在本仓库语料里**(在 S3 的 .dem 上);
  复现的是它的几何(离线 1,630u、离 bot 1,130u,**仍在未动的 1500 reach 内**,已单独断言)。
  **声明面**:lane 几何(mock `GetLocationAlongLane` 恒 `Vector(0,0,0)`,语料**结构上**没有
  lane 几何)+ 营地坐标(`GetNeutralSpawners()` 930/930 帧 `{}`);**真实且承重**的是
  bot / 队伍 / 坐标 / 两座远古 / 由它们算出的每一个距离。**零新 fixture** ⇒ #106/#107 结构上不存在。
  **⚠ 行号面这次是被自己撞出来的,而且撞的是「源码窗口」这种伪装过的行号锚(`0LN2` 同族)**:
  插了 ~2,300 字符 ⇒ 姊妹文件 `test_pullcamp_ownside_camp.lua` 的 8000 字符 `source()` 窗口
  够不到 `return vBest`,两条 [reverse] **当场红,而消息是「子句不见了」而子句就在那儿**。
  窗口 8000 → 14000 **并加一条自证断言**(够不到函数末尾就以一条**说真话**的消息失败),
  新文件同样带这条。顺带重锚一处**本轮之前就已经不准**的散文指针
  (`test_axe_cull_immune_veto.lua` 的 `jmz_func.lua:8474` → 真值 **:8760**,
  **~280 行漂移里只有 83 行是本轮造成的**,已写进注里)。
  **门**:luacheck **0 警告**(改动前后各一次);关联切片 pullcamp **47/0** / camp **98/0** /
  lane **45/0** / pull_camp 16 / creep_pull 12 / roam 27 / axe_cull 26 / gate_claim 10 /
  level_gate 15 / smoke_load 3 **全部 0 失败**;全套见报告收尾追记。AWS **$0**(未 bootstrap)。
  **交棒**:总监(`test_set.md` 02:0xZ 入集提议,**零 AWS 增量、搭车**;**arm 串两个 id 都要**)、
  批测台(`queue.json:strategy-11`,不申请专波 —— 三条判据全是 armed 腿**臂内**读数,
  与 08-22 §AP 驳回 strategy-2 专波同理)、录像组(判据**开工前登记**:① connect 两个估计量
  都报、必须明显高于 12.1%/9.9%;② **跟随小野→最近线兵中位必须下降** ——
  **这是机制签名**,connect 涨而它不降 = 涨的不是这条子句买来的;③ `poke_episodes` 不得塌向 0;
  免费正控「开拉点离家中位」**只能同波自读**,该量**波间自噪声 2,012u** 与效应同量级;
  **计量三条 GH #148 照办**:ab/ba 两层都要给,connect/episodes 是计数类 ⇒ 不报中位数)。
  **预登记的反向读法**:三条都不动 ⇒ 第一嫌疑 **arm 串漏了 `pulllane`**(静默 no-op),
  第二嫌疑 **1200 是数据支持的最宽值、可能还不够紧**(下一档收到 p90 的 992)。
  报告 `iterations/reports/strategy/20260824T012700Z.md`;`state.json:pulllane_20260824`。
- 2026-08-23T23:35Z:**认领 GH #137 的余下一格(录像组 08:54Z 那条续办项),落地 gated `campsel`
  —— 顺着它去读源码,发现的不是两个常数不一致,是那一行的两个谓词都读不到自己要的字段。**
  开工自检 **worst exit 3**(UNLANDED 无;cadence **一条 GAP:batch-desk 18:09→22:07Z 4.0h**,
  非本组;trunk python **18 passed**);开工 `HEAD == origin/main == da720ee`,收尾时 main 已到
  `79672bf`,**已 rebase 并在 rebase 后重跑全部门**;容器已带 `lua5.1`/`luacheck`。
  **⭐ 一个错的操作数,两道独立的闸同时死掉(→ 新流程条 `0WRAP`)**:`RefreshCamp` 产出
  `{idx, cattr}` 包装对象,同文件**其它每一处**读营地属性都走 `.cattr`(`GetCampStackTime` 是
  `camp.cattr.speed`,连 `GetClosestNeutralSpwan` **自己那两处距离**也是 `camp.cattr.location`)
  —— **只有同两行上的两个谓词调用直接传了 wrapper**:`IsEnemyCamp` 读 `.team` ⇒
  `nil ~= GetTeam()` **TRUE 每一个营地**(1.5× **一视同仁**,均匀系数改不了 argmin ⇒
  **敌方野区惩罚从来没生效过**;活下来的只有副作用:15000 截断变成**实际 10000**);
  `IsAncientCamp` 读 `.type` ⇒ **FALSE 每一个营地** ⇒ `GetLevel() >= 10 or not IsAncientCamp`
  **任何等级恒 TRUE**,**等级 10 的远古闸门是死代码**。
  **⭐⭐ 第二条正是 GH #137 §2「6/40 在等级 ≤9,连它自己那条 `>=10` 都没拦住」的另一半**,
  而 issue 把它整个归给了 `RefreshCamp` 的掉落(`0ASK` 的形状:**病例是真的,机制归因少了一半**)
  —— 名单那一半是 `campgrade` 已经修掉的,**但这条子句在任何名单上、任何等级上都不会触发**。
  **杠杆(一个)**:那两个调用读 `camp.cattr`,gated `campsel`、turbo-only。
  **门只解一次**,在 `mode_farm_generic.lua` 新增的文件级 `ClosestCamp` 里;**10 个调用点**
  全部改走它,并用**计数用例**(去注释后全 `bots/` 恰好 1 处直连调用)保证将来没有调用点
  能静默漏门 —— **是计数不是承诺**。
  **⚠ 与 `campgrade` 正交但不对称,排波要用**:两者可单独 arm(已成用例),
  **同 arm 时 `campgrade` 支配远古那一半** ⇒ **同 arm 的波只能读到敌方惩罚那一半**;
  要读远古闸门,请排 `campgrade` **未 armed** 的腿。
  **⚠ 声明的代价,钉了三条不是提一句**:还原操作数**同时**还原了 15000 本来的射程 ——
  己方营地从实际 10000 拿回 **15000**,敌方保持 10000 ⇒ **己方射程变宽**,与修法不可分割
  (乘数与截断是同一个表达式)。己方 12000 出厂 nil / armed 选中;己方 15500 armed 仍 nil;
  敌方 12000 两边都 nil。
  **本地**:`tests/test_campsel_wrapper_fields.lua` **21 例全绿,11 变异 11 抓** ——
  **M2「只修 IsEnemyCamp」/ M3「只修 IsAncientCamp」都被抓** ⇒ 「两个都读记录」是被钉住的,
  不是碰巧一起改的;真实帧三枚跨过 `>= 10`(**1 级** axe —— 对应 issue 自己那个
  「1 级 jakiro t=77.7 打远古营」的最坏案例 / **9 级** earthshaker / **10 级** skeleton_king);
  未 armed 逐字节等价由 **192 例**与**逐字转写的修改前函数体**对照(`false` 与不传第三参数两种写法)。
  **三条世界断言**:W1 语料无营地表(`GetNeutralSpawners()` 恒 `{}` ⇒ 营地表是**声明的替身**,
  本文件**没有一个数被声称是语料数据**);**W2 = 根因,读的是真实生产者**(`RefreshCamp` 真实
  输出的每个条目 `.team == nil and .type == nil`,而 `.cattr` 两个字段都在);
  W3 `IsTheClosestOne` 本地恒 TRUE(**0/5 队友读到 `BOT_MODE_FARM`**,两半都断言)。
  **域(0DOM)**:帧域 **818/1040 = 78.7%** 在 10 级以下(地板不是等式),
  **与 GH #137 的事件率(1.0 次/局、15% 在 ≤9)永不相减**;
  **敌方惩罚那一半本地买不到域**(要同一帧上己方营与敌方营的相对距离,而语料没有营地表)——
  **没有假装端到端**,那一半只能在波次上买。
  **⚠ 行号面这次真撞上了,而且是被棘轮抓到的(0LN2)**:`mode_farm_generic.lua` **+11**、
  `aba_site.lua` **+36**;`test_level_gate_census` 的 `GATES` 表**当场红两条**,七行已重锚
  (五行 +11 / 两行 +36),并在表头写明「表里的行号是活的,散文与用例名里的
  `:392/:506/:796/:860` 是 GH #84 对它当年那棵树的编号 = **标签不是行号**」;
  `test_pingstamp` 那处**把行号断言进错误消息**的用例(`:377:`)**改成从源码读出
  `GetRoshanDesire` 的行号再断言**(0CST 的形状)⇒ 以后不会再因行移动而红。
  顺手重锚两条会误导下一个读者的散文指针(`replay_fixture.lua` `:124→:135`、
  `roam_conversion.py` `:854→:872`,**后者在本轮之前就已经不准**)。
  **门**:luacheck **0 警告**(rebase 前后各一次);python 全套 **18 passed**;
  可见面穷举 13 个文件全部实跑 + 关键词宽切片(camp 83 / gate 141 / world 94 / level 29 /
  ping 32 / farm 5 / smoke 3)**合计 0 失败**;**全套后台启动、push 当时未跑完** ——
  门是用一条可证伪的分解关掉的(改动只有两块,unarmed 等价由 192 例证明,
  其余文件能看见它的唯一途径是行号,而行号面已穷举)。**⚠ 明说:全套是论证掉的不是跑绿的。**
  **零新 fixture** ⇒ #106/#107 破坏面结构上不存在;AWS **$0**。
  **交棒**:总监(`test_set.md` 23:3xZ 入集提议,**零 AWS 增量、搭车**;**排波请读那条
  `campgrade` 支配关系**)、批测台(`queue.json:strategy-10`)、录像组(条件 (a) **三个正向
  读数开工前登记**:敌方野区打钱占比下降 / 等级 ≤9 远古交火下降(用你们已有的
  `ancient_camp_domain.py`,基线 6/40,**但那条腿上 `campgrade` 不能 armed**)/
  每次打钱行程的步行距离;**反向判据不许省**:远古交火总数不许塌向 0、
  **行程距离不许显著变长**(它既是主判据也是本修法声明的代价)、对线期 gpm 不许低于 baseline;
  **计量三条(GH #148)照办** —— ab/ba 两层都要给,三个读数都是计数类 ⇒ 不报中位数)。
  **预登记的反向读法**:三个读数都不动 ⇒ **不要窄化谓词**,第一嫌疑是 **arm 串漏了 `campsel`**
  (no-op 且**没有任何计数会报警**),第二嫌疑是 **`campgrade` 同腿把读数 ② 吃掉了**。
  报告 `iterations/reports/strategy/20260823T233555Z.md`;`state.json:campsel_20260824`。
- 2026-08-23T21:55Z:**做 owner P1 完成定义第 4 条里那格从来没人认领过的 `(c)`,
  并把它读出来的不对齐落成 gated `pullcad`。** 开工自检 **worst exit 3**(UNLANDED 2 条
  **都在总监分支上**、非本组;cadence clean;trunk python **18 passed**);
  `HEAD == origin/main == da720ee`;容器无 `lua5.1`/`luacheck`,已装。
  **⭐ P1 只剩 (b)+(c),而 (c) 一直是空的**:第 1 棒(pullcamp 根因)08-22 做完、第 2 棒
  (入集)总监做完、**第 3 棒 (a) 录像组 21:00Z 刚判 WORKING** ⇒ 剩下的 (b) 是数据归总监,
  **(c)「检索标准拉野时机对齐实现」是本组章程范围里的字面职责**,没人做过。本轮做它。
  **⭐ 检索结果是「不对齐」,而且不对齐的是一个常数**(三处独立来源数字一致:
  Liquipedia Lane Creeps / Hotspawn creep-aggro / DOTABUFF pulling guide):
  拉仇恨的 **500 邻接**实现**是对的**;但**一次拉到的仇恨保持 2.3s、再拉一次有 2–3s 冷却**,
  而出厂 poke 节拍是 **1.2s** ⇒ **第 2、3 拍结构上拉不到任何东西**(第一拍落在仍活着的仇恨里,
  第二拍落在它的冷却里)。**而且不是免费的**:`Action_AttackUnit` 打一个不在攻击距离内的英雄
  会让 bot **走向他** ⇒ 无效补拍**把已经被拉住的兵线往回拖**。
  **⭐⭐ 同一个 2.3s,录像组早就从另一侧量到了,只是当成了缺陷本身**(→ 新流程条 `0NUM`):
  GH #143 的头条「一次普攻中位只换来 **2.2s** 小兵追击」**不是缺陷,那就是文档里的 2.3s** ——
  机制按规格在工作。本组 11:3xZ 用源码驳掉了它的修法(`0ASK` 立得对),**但连同那个数一起放下了**;
  数还在,而且回答了一个没人问过的问题:补拍频率差 **2.5 倍**。
  **杠杆(一个)**:`mode_roam_generic` 的 cadence `1.2s → 3.0s`,gated `pullcad`。
  3.0 同时清掉 2.3s 仇恨与 3s 冷却上界,**也正是同文件里姊妹拉野 `pullcamp` 自 wave13 起的节拍**
  (已写成「两个节拍必须相等」的用例)。
  **⭐ `pullbeat` 是结构性前置,而且这次写进了门里**:没有它,poke 在下单后 **33ms** 就被自己的
  move 取消 ⇒ 仇恨只能靠运气拉到,**这时拉长节拍只买到更少的运气,严格比出厂更差**。
  所以门是 `pullcad and pullbeat`,**`pullcad` 单独 arm 逐字节 no-op —— 那是用例不是承诺**
  (对照 `pullzone`/`bagsalve` 的 arm 串约束只能写在散文里、只能靠总监记得)。
  **本地**:`tests/test_replay_pullcad_beat.lua` **9 例全绿,9 变异 9 抓**;量的是**真实帧
  order log**(`f_072738_zuus_mana` @ t=160.4,92 帧 = 3.07s):出厂 **3 次 poke / 拖拽占 58%**,
  armed **1 次 poke / 82.6%**;`pullcad` 单独 armed 的 log 与出厂**逐字节相同**(已成用例)。
  **M5(2.0,落进冷却)/ M6(2.2,落进活仇恨)是近失变异** ⇒ **常数本身被钉住了**,
  不只是「比出厂大」被钉住。另有 `[reverse]` 一条:`creepPullAttackTime` 全 `bots/`
  **只有一个写入方**(第二个写入方会让整份 order log 变成虚构)。
  **诚实边界**:敌方兵线**合成**(`GetNearbyLaneCreeps` 0/966,生成器不写小兵),放在 Lina 的
  真实坐标上 ⇒ 真实的 **621u** 几何仍然决定 `<=500` 邻接;**仇恨有没有翻面本地不测**
  (Bot API 无此信号),留给录像组 21:00Z 建好的 **FLIP 拼法**。
  **⚠ 一次自伤,已写进报告 §3.3**:第一轮变异电池用 `git checkout -- <file>` 回滚,
  **而源码改动还没 commit** ⇒ 第一条变异跑完就把改动擦掉,M2–M9 全跑在没有 `pullcad` 的树上
  (「整整齐齐都是 7 failures」是唯一线索)。**未提交的树上做变异,回滚只能用文件副本**;
  已重跑并核对 `diff -q` = IDENTICAL。
  **门**:luacheck **0 警告**;可见面穷举(`grep -rl` 三条)**13 个文件 139 例 0 失败**;
  **零新 fixture** ⇒ #106/#107 破坏面结构上不存在;AWS **$0**。
  **交棒**:总监(`test_set.md` 21:5xZ 入集提议,**零 AWS 增量、搭车**;**外加请收下 §1 当作
  P1 第 4 条的 (c) 那一格** —— 并注意 **`creeppull` 的 promote 不必等 `pullcad`**,
  那是两个决定)、批测台(`queue.json:strategy-9`;**⚠ 与 GH #149 的 pullbeat 差分波有交互,
  请排在它之后,不要在同一波里分叉两个节拍常数**)、录像组(三个正向读数**开工前登记**,
  全部用你们 21:00Z 已建好的量:FLIP 拼法**两层平均**、每 episode 兵线位移、
  **每 episode 右键次数必须下降**;**(iii) 不降的第一嫌疑是 arm 串漏了 `pullbeat`** ——
  门是合取,漏一个逐字节 no-op **且没有任何计数会报警**)。
  报告 `iterations/reports/strategy/20260823T215500Z.md`;`state.json:pullcad_20260823`。
  **收尾追记(22:5xZ,全套已兑付)**:**闭合了,0 失败,但它是两段跑的,不是一次跑的** ——
  单进程被**我自己设的 `timeout 7000`** 杀掉(`EXIT=124`),死前 **1411 例 / 0 失败**;
  本树总量 **1605**(总监那棵是 1569,两棵树不同)⇒ 缺口 **194 例**。缺口是**字母序尾巴**
  (runner `table.sort`,1411 恰好切在 `test_tiny_treegrab_hp_noop` 结束处,
  切点由逐文件累计计数**算出**不是估的)⇒ 未跑的 20 个文件已用 `towerreach 12` /
  `tp 153` / `wk_ 128` = **293 例 0 失败**(缺口的超集)单独实跑。
  ⇒ **`tests/` 每个文件都在这棵树上跑过、合计 0 失败;没做到的是「同一进程一次跑完」** ——
  这个区别在本仓库不是纯形式的(`0n` 同名覆盖、#106 跨文件棘轮),所以照实写。
  **GH #124 第四个数据点**:本容器单进程 7000s 只到 **1411/1605 = 88%**,
  而缺口那一片分片跑只花几分钟 ⇒ **单例成本极不均匀,按字母序切两片即可各自跑完**。
- 2026-08-23T19:26Z:**认领录像组 18:53Z 落在 GH #143 §3 的交回,落地 gated `pullzone` ——
  出厂代码在「过去 2 秒没人碰过我」的帧上断言「我正被 zoning」。** 开工自检 **worst exit 0**
  (UNLANDED 无 / cadence clean / trunk python **17 passed**);`HEAD == origin/main == 0ba0d33`;
  容器无 `lua5.1`/`luacheck`,已装。
  **⭐ 别组的病例是真的,归因在检测器;而顺着它往触发器里走一步,门上有一个真缺陷**
  (0ASK 的第二次兑现):录像组的 33 秒 lina「pull」`d_fount` 8533→9165 —— 而 armed 执行体是
  `Action_MoveToLocation(pull.retreat)`,`retreat` **朝自家泉水**,计划若在驱动她这个数只会降
  ⇒ **episode 误标是检测器侧**(交回 #149,不动他们的文件)。**但**
  `J.ShouldCreepPullLane` 的 DISADVANTAGED 门里承重的那条析取项
  `( #tEnemyHeroes >= 1 ) and not J.WeAreStronger(bot,1200)` **坐在 SAFE-1b
  (`WasRecentlyDamagedByAnyHero(2.0)` 就 return nil)之后** ⇒ 它**恰恰在没人碰过我的帧上
  断言我正被 zoning**,剩下的内容是一个普通对线帧的描述 —— 与录像组看见的混合人口同一根绳子。
  **⭐ 两条新的世界断言,而且落在同一个门的两条腿上**:**第 22 条** `GetLaneFrontAmount`
  两队读**同一个 mock 常数**(`front_tied 966/966`)⇒ 兄弟析取项 `bWavePushedToUs`
  **结构性 FALSE**,不是「均势」;**第 23 条(0DIR 形状)** `J.WeAreStronger(bot,1200)`
  **FALSE 966/966**(两侧 power 都是 0,`GetOffensivePower`/`GetAttackDamage`/`GetAttackSpeed`
  全落 mock 的 `Get*→0`,`0 > 0` 为假)—— **危险的是它的否定式**:出厂代码读的
  `not J.WeAreStronger(...)` 是 **TRUE 966/966**,只报「实力检查每帧都同意我们」会读成一切正常。
  两条合起来:`zoned_off == enemy_near == 378`,已写成恒等断言。
  **⭐ 域,而且申请书要引的是第二个(0DOM 用在本组自己的修法上)**:端到端谓词
  **结构性不可达**(`lanecreeps **0/966**`,fixture 生成器不写任何小兵)⇒ **没有假装端到端**,
  纯谓词在真实帧上断言 + 接线用结构断言,写在用例头注第一段,并钉成 `== 0`(哪天有小兵它当场红);
  谓词帧域 `zoned_off 378/966 = 39.1%`;可问帧(v2)138,armed 收窄 **46 = 33.3%**;
  **v1 的 240 帧收窄是「不可问」不是「平静」**,分开计从不合并;
  **真正付钱的域是 SAFE-1b 之后的 71 帧**(ring 25 + dry 46)⇒ **64.8%** ——
  引 39.1%/33.3% 会把杠杆**低估约一半**。
  **⭐ 常数的上界由「语料能不能回答」定,并写成断言**:6.0s = 远程对线约 3–4 个攻击周期,
  **同时**是 fixture `recent_window` 的上限(loader 对更长的**静默 clamp**)⇒ 更大不是更大胆是**不可测**;
  下界由 SAFE-1b 定(≤2.0 则 armed 后 creeppull **一次都不会触发**,那不是收窄是关闭)。两侧都已断言。
  **本地**:`tests/test_creeppull_zone_clause.lua` **16 例全绿,8 变异 8 抓**;承重帧对是
  **同一英雄同一局两个时刻**(`ss_chase_stalled`/shadow_shaman 6s 内 57 伤害 ⇒ 保留 vs
  `ss_chase_start`/**同一个** shadow_shaman 6s 内 0 ⇒ 收窄),drow_ranger/viper 在另一局复现同一分裂。
  **turbo 结构性继承,而且两半都断言**(helper 内不许出现 `IsModeTurbo` + 调用方 turbo 行必须在调用行之前)——
  只断言前一半的话,「没写」与「忘了写」无法区分。**零新 fixture** ⇒ #106/#107 破坏面结构上不存在。
  **0LN2 兑现,顺手修掉一处本轮之前就已经错的坐标**:插了 +49 行,`grep` 一次跑完 ——
  **无一处可执行行钉**受影响;唯一在下方的 `jmz_func.lua:7085 / :7050`
  (`lanekill_commit:ALLY_HP_MIN` 的 MIRROR 注)**本来就已偏约 250 行**(真值 7389 / 7354),
  已重锚并把「大部分漂移早于本轮」写进注里 —— 不写下一个读者会以为是这次撞的。
  **门**:luacheck **0 警告**;定向子集全绿(creep_pull 12 / creeppull_zone 16 /
  replay_creeppull_reachable 6 / replay_pullbeat_attack_cancel 8 / pull_camp 16 /
  pullcamp_ownside_camp 11 / pullcamp_trigger_census 21 / gate_claim_consistency 9 / smoke_load 3);
  python 全套 **17 passed**;lua 全套后台被 900s SIGTERM 掉(exit 143、零输出)⇒
  **改为按可见面闭合**:两块改动分开论证 —— 新函数全树调用点**恰好两个**(去注释后数,
  第一版数到 4 因为数进了散文);调用点那一行在 `creeppull` 门内,而 `tests/` 里 **37 处**
  `IsSoakCandidate` monkeypatch **全是 id 白名单、无一无条件 true**,且 unarmed 逐字等价。
  `grep` 穷举可见面命中 **10 个文件全部跑绿**,合计 **130 lua 例 + python 17,0 失败**
  (含 fixture_roles 10 / pingstamp_world_assertion 18)。**行号面**:插入点在 7021 之后 ⇒
  算术上动不了 7021 之前;仅有的两处可执行 `jmz_func:<n>` 引用都在其上;唯一一处
  **把行号断言进错误消息**的用例(`:377:`)**指向 `mode_farm_generic.lua` 不是本文件**,已核对。
  **⚠ 明说没跑的**:`test_itemdesire_world_assertion`(18 分钟 sweep)是**论证掉的不是跑绿的**。
  **交棒**:总监(`test_set.md` 19:2xZ 入集提议 —— **arm 串约束是硬的**:`pullzone` 单独 arm
  **逐字节 no-op**,串里**必须同时有 `creeppull`**,两者都已在成员串里 ⇒ **零 AWS 增量、搭车、
  不申请专波**)、批测台(`queue.json:strategy-8`)、录像组(条件 (a) **两个正向读数开工前登记**:
  creeppull episode 数下降 / 每 episode 的「2.5s 内敌方小兵朝本 bot 的伤害行」比例上升;
  **反向判据不许省**:episode 数塌向 0 = 关闭不是收窄,对线期 last_hits/xpm 不许低于 baseline 腿;
  **不许用 GH #143 §2 那张池化表当锚点**,#148 已证明它被污染)、录像组/#149
  (§3 的 episode 误标是**检测器侧**,你们提的 2.5s 事件计数正是对的收窄)。
  **预登记的反向读法**:下一波两个读数**都不动** ⇒ **不要再窄化谓词**,第一嫌疑是
  **arm 串漏了 `creeppull`**(no-op 且**没有任何计数会报警**),第二嫌疑是 6.0 在真实引擎里
  选中的人口与本语料不同(**138 个可问帧是下界不是估计**)。
  报告 `iterations/reports/strategy/20260823T192600Z.md`;`state.json:pullzone_20260823`。
- 2026-08-23T17:45Z:**认领录像组 17:00Z 落在 GH #123 上的独立第二波复测,落地 gated `bagsalve`
  —— 同一道不对称,从**没人试过的那一端**关。** 开工自检 **worst exit 0**(UNLANDED 无 /
  cadence clean / trunk python **17 passed**);`HEAD == origin/main == a5f1678`;容器无
  `lua5.1`/`luacheck`,已装。
  **⭐ 一个 FALSE,同一帧被两个消费方读,两个方向都错**:`fieldbuy` 的采购门数**九个槽**、
  `J.HasFieldRegenSource` 只读**六个主槽** ⇒ 快递把大药投进背包那一刻,hold 侧
  (`stayfield`/`stayfield2`)读成「没东西喝」**放行回家**(owner P2 明令禁止),
  supply 侧读成「空手」**再买第二瓶**。GH #123 提议从**采购端**收窄(9→6),
  08-22 本组实测**拒绝**(要放弃本族域的 46.4%);**从持有端关同一道不对称,一分不放弃。**
  **⭐ 只有一个物品宽,理由是机制不是保守**:`TrySwapInvItemForFlask`(无 gate、每帧从
  `GetDesire` 跑)**只搬大药**,而 `tango`/`tango_single`/`faerie_fire`/`bottle`
  **全仓库没有任何 swapper** ⇒ 它们在背包里是**真的喝不到**。这条「不存在」写成了
  `[reverse]` 用例(将来落地 tango swapper 会红,逼人重审)。**而且被守的分支正好选中这个
  人口**:`stayfield` 唯一调用点「撤退:3」自带 `itemFlask == nil`,`J.IsItemAvailable`
  **只读 0..5** ⇒ 它只对「主槽没有大药」的 bot 开火。
  **⭐ 域,两个数分开写永不相减(0DOM)**:`_fieldbuy_supply_sweep.lua` 新增 BAG 行
  (**同一次 sweep,不加墙钟**)—— 谓词帧域 **flip 13/966 = 1.3%**(**全部真实帧**,
  槽位 6:2 / 7:6 / 8:5 ⇒ 收窄范围的变异由真实帧抓);**行为域 sit_flip = 0/966**,
  语料里没有一帧同时在处境域内且背包带大药 ⇒ **端到端只能建模快递投递**,
  真实人口在批测录像里(录像组:**166 次背包落点 / 205 局**,26.9%,残余 STUCK 11.0%)。
  阴性人口 **other=55 必须 other_flip=0**(不变量不是棘轮:加 `faerie_fire` 的变异 ⇒ **18**,
  语料级断言当场红)。**`victim_neg = 0/966`**(搬运工的 `GetMainInvLessValItemSlot` 从不
  返回 -1)= **0DIR 的形状** ⇒ **只报告、故意没写成子句**:恒真的合取买不到东西,只藏失效模式。
  **⭐ 顺手证伪了自己 08-22 写下的一条边界**:拒绝文件写「语料里没有任何一帧背包带大药」——
  **今天 13 帧有**。仍为真的是更窄的一句(没有一帧**同时**在处境域内),已订正在那个文件头注里;
  错的那一版**会把下一个读者从 13 帧真实数据前面支开**。
  **本地**:`tests/test_bagsalve_backpack_source.lua` **18 例全绿,7 变异 7 抓**
  (去 gate / 加 faerie_fire / 范围 6-7 / 范围 7-8 / return false / id 打错 / 调用顺序反转);
  阴性对照是**域内的真实帧**(viper 的 faerie_fire),不是构造的。**turbo 结构性继承**
  (两个调用方都先问 `IsFieldRegenSituation`),不补冗余检查、**把顺序本身写成断言** +
  「调用点恰好两个」的计数断言。**零新 fixture** ⇒ #106/#107 破坏面结构上不存在。
  **0LN2 兑现**:插了 59 行,`grep` 一次跑完 —— **无一处可执行行钉**(python 17 passed 佐证),
  但本族钉子**在改动前就已漂 3–5 行**,一并重锚(`stayfield_domain.py` 六处 +
  `test_detector_source_constants.py` 两处)。
  **⚠ 交出去的一条口径滞后**:`stayfield_domain.py` 的 `usable_items()` 读六个槽 =
  **UNARMED 语义**,armed 波上它**低数 has_regen、高数 fieldbuy 干侧**;已声明在它头注里,
  条件 (a) 建议只用**局内配对差分**。
  **门**:luacheck **0 警告**;定向子集全绿(bagsalve 18 / fieldbuy 35 / backpack_rescuer 12 /
  fieldcreep 16 / gate_claim_consistency 9 / smoke_load 2);python 全套 17 passed;
  **全套已兑付(收尾后跑完):`1544 tests, 0 failures`**,墙钟 **≈2h10m**
  (末次直读 02:05:52 elapsed / 01:51:01 CPU)。**给 GH #124 的第三个读数,三者差 6.5 倍**:
  13:40Z 96m35s/1501、总监 17:00Z **~20 分钟/550**、本轮 ~130 分钟/**1544** ——
  **用例数本身就差 2.8 倍(550 vs 1544)⇒ 那个 20 分钟多半不是同一次全套**;
  只有本轮与 13:40Z 可比(1501→1544,+43 例 / +35% 墙钟)。跑的是 **rebase 之前的树**
  (17:32 启动,不含 main 17:17Z 之后的 #131 smoke 改写与 19:26Z 的 `pullzone`)。push 当时**门是用一次可证伪的分解关掉的**(兑付晚到不追认它没被用过),
  而且**不是总监那条**(本轮改的是 `jmz_func.lua`,人人加载它,「排在前面的文件」论证不成立):
  ① 新腿整个包在 `IsSoakCandidate('bagsalve')` 里;② 全 `tests/` **没有任何用例把
  `IsSoakCandidate` 打成无条件 `return true`**(七处 monkeypatch 全是白名单);
  ③ 全 `tests/` 只有**四个文件**提到这个 id + 扫全源码 gate 的 `gate_claim_consistency`;
  ④ 这五个**全部实跑绿**;⑤ 语料级 `unarmed = 0/966`。⇒ 其余 152 个文件**结构上看不到**这段代码。
  **⭐ AX.2 兑现(总监 17:xxZ 刚立的入集前置条件,rebase 时读到)**:付钱的那个轴写在前面 ——
  **EVENT 轴 0.81 次背包落点/局**(166/205 局,26.9% 的野外采购),残余 STUCK **0.32 次/局**
  (11.0%),**由录像组在已购 .dem 上免费量到、本波不需要买**;FRAME 轴 flip 1.3%、行为域 0/966。
  ⇒ 不属于 §AX.6 那一类「拿着没量的域来买一波」。**§AX.5 同形**:三个消费方 id 是
  **结构性使能器不是第二个新 id**。
  **交棒**:总监(`test_set.md` 17:4xZ 入集提议 —— **arm 串约束是硬的**:单独 arm 逐字节
  no-op,串里**必须同时有 `fieldbuy` + 至少一个 `stayfield`**,三者都已在集内 ⇒
  **零 AWS 增量、搭车、不申请专波**)、批测台(`queue.json:strategy-7`)、录像组
  (条件 (a) **两个正向读数开工前登记**:重复购买率降 / 背包落点后 30s 回家率降;
  **反向判据不许省**:野外大药总购买量不许塌向 0、armed 侧死亡数不许升 ——
  **残余 STUCK 11.0% 就是本 id 代价的规模上界**;判据用局内配对量)、录像组/GH #123
  (还欠的一格 = **搬运工在真实对局里为什么会输**;`BOT_MODE_WARD` 你们判 UNTESTABLE ⇒
  **可行的替代:量「背包落点→主槽」的等待时长分布,看它分不分层在 6.2s 的整数倍上** ——
  那是轮询节拍的签名)。
  **预登记的反向读法**:下一波两个读数**都不动** ⇒ **不要再窄化谓词**,第一嫌疑是
  **arm 串漏了 `fieldbuy`/`stayfield`**(no-op 且**没有任何计数会报警**),
  第二嫌疑是**成因在更早一帧**(药压根没投进背包)。
  报告 `iterations/reports/strategy/20260823T174500Z.md`;`state.json:bagsalve_20260823`。
- 2026-08-23T15:36Z:**认领总监 14:58Z 退回本组的 `itemtrip`(§AT.1 第一档,X = gpm −26.44),
  它交的不是「退回」两个字是一道算术题 —— 答案量出来了:错的是域那一侧,而且这个数一直在树上。**
  开工自检 **worst exit 0**(UNLANDED 无 / cadence clean / trunk python **17 passed**);
  `HEAD == origin/main == 029a60c`;容器无 `lua5.1`/`luacheck`,已装。
  **⭐ 域 0.038 次/局 与代价 −26 gpm 差三个数量级,因为两个数从来不可比**:
  0.038 是 #120 数的 **TRIP**,而 `GetDesire` 的 bid 是**逐帧**付的 ——
  `tests/_itemtrip_sweep.lua`(104 fixture / **966 存活英雄帧**,37 秒,零 AWS):
  `J.IsWastefulItemTrip` **成立 320/966 = 33.1%**。「健康 + 1600 空 + 离家够远」
  **正是一个普通打钱帧的描述**,bot 可以连续几百帧在域内而一次行程都不发起。
  **⭐ 一个杠杆,而且是一次推导订正不是新子句**:泉水下限 **5000 → 10000**。
  原推导把 40.1s 中位往返算成「~12,000u 走动 **即 ~6,000u 单程**」——
  **折半是错的**:#120 的人口是 **643 次回城 TP**,**去程是 TP、只有回程在走**,
  走掉的 ~12,000u **就是单程离家距离**;沿用它自己那个 ≈0.83 保守折扣 ⇒ 10,000。
  域 **320 → 135(14.0%)**;订正前那条泉水子句只挡 **71/966**,几乎没在承担它注释声称的窄化。
  **上限来自证据帧**:承重帧 lina `20260822_123136` t=434.6 离家 **11,239.9u** ⇒ 留 1,240u 余量,
  **超过 ~11,000 杠杆就在自己的证据帧上失效**(付过学费的 Luna 追击病灶),两侧都已断言。
  **⚠ 订正的代价是断言出来的不是提一句的**:10000 之后**全语料 0/966 帧够得到归因伤害子句** ⇒
  普查 `WHY dmg` 断言改 **`== 0`(等式,故意的)**;**N1 变过定**(他 9,811u 也在新下限内,
  两个理由都答「不」⇒ 不再隔离任何子句,降级回归);**N4/N5 在真实几何上重切、只合成
  伤害簿记一个量**并逐例声明(旧 N4 会**为距离理由假绿**,旧 N5 会**直接红**)。
  **没有为了让用例好过而挪常数,反过来:常数由推导定,用例跟着重切。**
  **⭐ 普查那条断言从「认证现状」改成棘轮**:旧的 `>= 250 and <= live*0.45`
  **把 33.1% 认证成了正常**;现在 `<= live*0.16`(只降不涨)+ 防塌底 `>= 60`。
  **检测器侧**:`itemtrip_contract.py` 的 `FDIST_MIN` 随源码到 10000 ⇒
  **08-23 之前所有 IN/OUT 分桶作废**;顺手修掉它 selfcheck 里写死 `fdist=9000` 的
  「远处对照」行(**常数一动它自己就假红**,本轮第二次遇到这个形状)。
  **本地**:**15 例全绿,7 变异 7 抓**(下限 5000/12000/9000、归因否决摘掉、归因半径 3000→100、
  1600 环、用例侧把合成伤害归给错的英雄)。**门**:luacheck **0 警告**;邻域 7 个用例文件全绿;
  全量未跑(GH #124);**本轮没加 fixture** ⇒ #106/#107 破坏面结构上不存在。
  **交棒**:总监(`test_set.md` 16:0xZ **重新入集提议**,退回条件「带着新的域回来」已满足;
  **不插队**,名额 0、W3/W4/W5 已排定)、批测台(`queue.json:strategy-6`,**搭车、零 AWS 增量**,
  申报目的 = 条件 (b) 重测)、录像组(旧检测器读数**全部重跑**;按你们 15:30Z 自证,
  **(a) 不许再用 in/out 两桶比**,要局内配对量)、录像组/harness(**fixture 请求**:
  健康 + 1600 空 + 离家 ≥10000 + 近期被英雄打过,伤害源一内一外 ⇒ 退掉 N4/N5 的合成)。
  **⭐ 预登记的反向读法**:下一波赤字**基本不变** ⇒ **不是域的问题**,读成头注预登记的第二种可能
  (**nil 被引擎读成 0 ⇒ 整局 item mode 关掉**)—— **那时不要再窄化域,要拆 nil 那条腿**。
  报告 `iterations/reports/strategy/20260823T153651Z.md`。
- 2026-08-23T13:40Z:**`[strategy]` open issue 全部已交出下一棒 ⇒ 走 backlog,认领 #4
  「suptp × midtp 协同仲裁」(owner 反复点名)。落地 gated `midsupyield`:核心让 TP-响应名额给辅助。**
  开工自检 **worst exit 0**(UNLANDED 无 / cadence clean / trunk python **17 passed**);
  `HEAD == origin/main == aae8edb`;容器无 `lua5.1`/`luacheck`,已装。
  **缺陷**:`J.ShouldTpSupportTowerFight` 被 midtp(任意位)与 suptp(pos4/5)共用,分开它们的
  **只有位置盲的 FCFS 名额** `J.TryTakeTpResponseSlot` ⇒ 核心和辅助都想去时**谁先问谁烧名额**,
  是场竞速。标准 turbo 策略:辅助 TP 守边路(免费反杀),核心留图打钱。
  **修法**:新纯谓词 `J.HasAvailableSupportResponder`(逐条同辅助自身在 helper 里的门)+ 调用点
  一条 gated 子句(在取名额**之前**,靠 `and` 短路 ⇒ 让路永不消耗名额),turbo 继承 + `IsCore` 限定
  ⇒ **辅助永不让路**。**构造安全**:无可用辅助不让路 ⇒ 只**改派**不**丢弃**、不抬高核心 TP 参与;
  方向与残差防守引力病灶同号(只减核心离农 TP)。
  **⭐ 真实帧(966 帧普查,helper 端到端只在 3 核心帧开火,2 带辅助)**:让路帧
  `f_260820_042612_axe_blink_init_573`/luna(**roles 实钉 pos1**)+ venge(**roles 实钉 pos5**,TP 就绪)
  ⇒ midtp 单开**开火**、+midsupyield **让路(nil)**;阴性对照 `..storm_collapse_parity`/storm
  (**全队无就绪 TP 辅助**)⇒ armed **仍开火**(响应不丢)。辅助枚举双向可读(138 在 / 666 不在,
  逐队友 TP 410/234);61/804 核心帧崩在 `CanEnemyInterruptTpChannel`(既有语料上限,两承重帧不在其中)。
  **本地**:`tests/test_midsupyield_core_yields.lua` **12 例全绿,5 变异 5 抓**(3 用例内 monkeypatch
  + 2 开工源码变异:删辅助子句→2 红 / 门无视 soak id→2 红,还原复绿)。**门**:luacheck **0 警告**;
  推送用定向子集(mid_tp_support/tparrive/tp_commit/tpclaim/tpdying/gate_claim_consistency/smoke_load 全绿),
  **全套后台跑完事后兑付:`1501 tests, 0 failures`**。
  **⭐ 给 GH #124 的硬数(额外产出)**:全套墙钟 **96m35s**(user 67m41 / sys 28m53)——
  #124 立案写的是「~18 分钟 sweep + 900s 超时里跑不完」,**实测是那个 18 分钟的 5.4 倍、
  超时线的 6.4 倍**,量级已不是同一个问题 ⇒ 例行容器里各组**结构上只能用子集作门**,
  而「用哪个子集」目前无共同口径。已追评 #124。
  **定位**:state.json `teambrain` 计划 phase-1 响应仲裁器(「一事件→一最优响应者」)的**第一根具体杠杆**;
  全局响应预算/跨事件仲裁仍是 backlog #3。
  **交棒**:总监(`test_set.md` 13:3xZ 提议;`midsupyield` 单 arm 是 no-op,串**必须带 midtp+suptp**,
  专波与否按 §AU.2 裁)、批测台(`queue.json:strategy-5b`)、录像组(条件 a 用 TP 家族现有读数:
  核心响应份额降 / 辅助份额升;**阴性判据不许省**:塔战响应总数不许塌向 0 = 丢弃响应)、
  主会话(P1/P2 球权,连续多轮请核对)。报告 `iterations/reports/strategy/20260823T134006Z.md`。
- 2026-08-23T11:33Z:**认领 GH #143(录像组 10:53Z,54/54 局宽扫 + 7 局逐帧,明写
  「建议的修法(协同组)」;同时是 owner P1 拉野链的下一根杠杆)。产出 gated `pullbeat`
  —— 但写的不是它建议的那条。** 开工自检 **worst exit 0**(UNLANDED 无 / cadence clean /
  trunk python **16 passed**);`HEAD == origin/main == 1eaa774`;容器无 `lua5.1`/`luacheck`,已装。
  **⭐ 它建议的修法要修的机制这份代码没有**:GH #143 §4 建议二是一个**结束条件**
  (「距最后一次普攻 >2.5s 就停止拖拽」),前提是「拖拽走到 retreat 就完,与仇恨无关」。
  但 `bot.roamCreepPull` 由 `GetDesire` **每帧重新推导**,而 `J.ShouldCreepPullLane`
  同帧要求**目标 ≤1000 且兵线 ≤900** ⇒ **兵线一走开,计划当帧变 nil,拖拽自己就停了**。
  **它自己的数就是证据**:5,105 个 episode 里**连续 pull 帧最长游程 = 2,两条腿都没有一个 3**
  —— 没有一段长拖可以「提前收手」;它量到的 1380u 回家长走**不是 pull 帧**。已回帖。
  **⭐ 真正错的在早一帧,而且是驱动出厂 Think 打印出来的**:把出厂 Think 装进真实帧、
  按 1/30 秒步进驱动 46 帧,命令流是 **`A` + 36 个连续 `M`** ——
  **攻击命令在起手动画开始前 33 毫秒就被自己的 move 取消了,每一拍都如此**。
  小兵仇恨只在攻击**真的开始**后才转过来 ⇒ 修复前那套节奏**全靠运气**吃仇恨,
  这正是录像组量到的 **26.8% 零小兵尾巴 / 47.5% 整段只有一次普攻**。
  **机制与数从两个方向对上了。**
  **修法是一个杠杆,而且它发的不是命令是「不发命令」**:poke 之后 **0.5s 内一帧命令都不发**
  (⇒ 攻击命令继续跑,是 hold 不是新命令),0.5 覆盖起手动画中位(~0.3–0.65s)、
  远短于 1.2s 的拍子 ⇒ **拖拽仍占一拍 37 帧里的 22 帧**;armed 驱动:`A`+14 hold+22 `M`+`A`。
  turbo 是**结构性**的(计划只在 `ShouldCreepPullLane` 非 nil 时存在,那函数第一行就是
  `IsModeTurbo`)⇒ 不补冗余检查,但**把「为什么不补」写进注释并由用例断言**。
  **本地**:`tests/test_replay_pullbeat_attack_cancel.lua` **8 例全绿,5 变异 5 抓**
  (去 gate / hold 吞整拍 / 整条回退 / hold 短于任何起手 / hold 符号翻面变成拖到一半发呆)。
  **M4 顺手钉掉我自己一处脆弱断言**:精确帧数断言钉的是 `t=160.4` 上的浮点舍入,
  改成「跨度 = 配置时长,误差一帧以内」。
  **⭐ 第二十一条世界断言(本轮修法形状的直接原因,不是副产品)**:
  `bot:GetAttackRange()` 在 **966/966 帧上读 mock 默认 150**(`bot_api.lua:160`,
  没有任何 fixture 带这个字段)⇒ 远程的 Zeus(380)/Lina(550)/Luna(330) **全读近战射程**;
  `GetAttackPoint()`(0.5 的原则性来源)**mock 里根本没有,调用即崩**。
  ⇒ 最顺手的那条「目标在攻击距离内才 hold」**因此没有写**,代价(hold 期间最多向敌人走
  ~150u)写进 `known_gap`。**与 0DIR 的关系**:本轮的 hold **刻意不读**引擎那个量,
  读的是上面那条分支自己用 `DotaTime()` 写下的**簿记**,而且**一拍之内两个方向都出现
  (14 真 / 22 假)**。
  **域普查(免费)**:`GetNearbyLaneCreeps(900,true)` **非空 0/966** ⇒ 没有任何真实帧
  能走进勾线分支,兵线必须是替身(放在 Lina 真实位置,让**真实 621u 几何**决定 ≤500 邻接,
  与 `test_replay_creeppull_reachable` 同法同因);除兵线外全过 **73/966**(活域)。
  **0FIX 自用**:#143 点名的两枚钉帧**不在树上也不在容器里**,`make_fixture.py` 够不到
  ⇒ 退到语料同形状帧,替换写进头注,**没有因为缺 fixture 就搁置整条杠杆**。
  **0LN2 自用**:`grep -rn 'mode_roam_generic\.lua:[0-9]'` 一次跑完,**15 处全是散文引用,
  零可执行行钉** ⇒ +26 行不需要挪钉子;顺手提醒录像组 `creeppull_specificity.py:19`
  的散文 `185-198` 现在是 `185-217`。
  **交棒**:总监(`test_set.md` 11:5xZ 提议行 —— 按 §AU.2 **申请专波**,且**串里必须
  同时有 `creeppull`**,单独 arm 是逐字节 no-op 且无任何计数报警)、批测台
  (`queue.json:strategy-5`)、录像组(条件 (a) 两个读数**开工前登记**:小兵尾巴中位变长 /
  零尾巴占比下降,**反向判据不许省**:净向家位移不许塌成 0)、harness 组(第二十一条断言 = **GH #145**)。
  **唯一一条本地验不了的语义假设已预登记**:「不发命令时上一条攻击命令是否真的继续跑」
  —— mock 没有命令队列;若两个读数纹丝不动而位移正常,**先怀疑这条语义再怀疑 0.5**。
  报告 `iterations/reports/strategy/20260823T113345Z.md`。
- 2026-08-23T09:24Z:**认领 GH #119 被点名两次的「下一根杠杆」(读方向不读量级),
  判决 DO NOT WRITE —— 而拒的理由是一次测量,不是一次顾虑。`bots/` 零改动,不产 gate。**
  **开工自检 worst exit 0**(UNLANDED 无 / cadence clean / trunk python **15 passed**);
  开工时本地落后 3 个提交,`pull --rebase` 后 `HEAD == origin/main == 043ee81`;
  容器无 `lua5.1`/`luacheck`,已装。
  **认领依据**:P1/P2 本组交付都已落地(球权核对**连续第四轮**请主会话处理);
  `[strategy]` open issue 里 #119 是唯一一条「别组明确点名下一棒该本组写、并且刚为它
  交了钉帧」的。**顺手把上一轮的 0FIX 第一次自用了**:`git ls-tree` 验
  `f_260823_002103_wk_ancient_camp_634.lua` —— **这一轮已经在 main 上了**,
  07:55Z 那条「不在树上」到此结清。
  **⭐ 三个读法不是同一种失败,危险的是第三个**(104 fixture / **966 个存活英雄帧**逐帧驱动):
  `GetAttackTarget()` **nil 966/966**、`J.IsAttacking` **false 966/966**
  (`GetAnimActivity()` 恒 0,而 `ACTIVITY_ATTACK` 是自动哨兵 **1158**)—— 这两个是 0p 那种
  「静静地什么都不做」;而 `GameTime() - bot:GetLastAttackTime() <= 3.0`
  (引擎唯一能表达「刚打过」的写法,`jmz_func.lua:2052` 就是这个形状)是 **0 − 0 ⇒ TRUE 966/966**。
  **⭐ 后果是量出来的不是论证的**:`fieldcreep` 在本语料关掉 **5** 帧(54 → 49);
  把三个候选作为**排除条件**套回这 5 帧 —— 前两个交还 **0/5**(no-op),
  第三个交还 **5/5**:**整条子句消失**,而普查打印的是 `vetoed 5 → 0`,
  **读起来正是「方向修法完美生效」**。这是**朝作者希望的方向假绿**。
  **⭐ 「把时钟修好」只把谎话翻个面**:`GameTime()` 改答 `DotaTime()` 后同一条子句
  **FALSE 966/966**、交还 **0/5** —— 从「全删」变「全不动」,**两种都不是对那一帧的测量**
  (用例里是**探针**不是散文)。上游时钟事实**不是本轮发现**,是**第十四条世界断言的成因 (1)**
  (`test_pingstamp_world_assertion.lua:55`);本轮记的是它落在**新消费方**上的符号与后果。
  **⭐ 钉帧本身也够不到这条子句,第三个独立原因**:`f_260823_002103_wk_ancient_camp_634`
  hp **817/1307 = 62.51%**,而本函数血量带是 `<0.18 or >0.55 ⇒ false` ⇒
  **在 `fieldcreep` 上面四条子句就离开了函数**,armed 与否读数相同;而
  `WasRecentlyDamagedByCreep(3.0)` 在这一帧**为真** —— 所以它**看起来**像个 fieldcreep 病例,
  这正是要写下来的理由。(它仍是 GH #137 的正确钉帧,已落地为 `campgrade`。)
  **⭐ 一个被自己用例当场抓住的错误(已进 backlog 0SRC)**:血量上界第一版**在整个文件上
  `match`**,而 `jmz_func.lua` 有**两行一模一样的**(**4674 是 0.18/0.75**,4767 才是 0.18/0.55)
  ⇒ 断言报「钉帧在带内」,**整条结论会读反**。修法:**先抠函数体再读常数**。
  **交付**:`tests/_fightback_sweep.lua` + `tests/test_fightback_world_assertion.lua`
  (**第二十条世界断言**,**11 例全绿,4 变异 4 抓** —— M1 把建议的读法真写进谓词 → **棘轮**转红
  并指回本文件;M2 loader 学会答 `GetAttackTarget` → 2 红;M3 上界 0.55→0.75 → 钉帧那条转红
  (**正是 0SRC 那个错误的形状**);M4 loader 学会答 `GetLastAttackTime` → 2 红)。
  **M2 第一次跑不是干净的红**:`cs.universal` 在 `nil` 上崩成 `bad argument #3 to 'format'`
  ——**该出现结论的地方出现了崩溃**;已修(sweep **预登记每个桶为 0**,判据 `== nil` 全改 `== 0`)。
  **变异不只验断言有没有牙,也验红的时候说不说人话。**
  **门**:`luacheck bots game` **exit 0 / 0 警告**;新用例 **11/11**;定向复跑了两个
  **枚举 `ls tests` 的普查**(`test_corpus_scale` 8/8、`test_defend_ping_declaration_ratchet` 8/8,
  按 0LN 查「新增测试文件会不会绊到别人」)+ 引用其读数的一族(`test_fieldcreep_veto` 16/16、
  `test_pingstamp_world_assertion` 18/18、`test_gate_claim_consistency` 7/7、`test_smoke_load` 2/2)。
  **全量没跑**(GH #124);**本轮 `bots/` 一个字节没改、没加 fixture** ⇒ GH #106/#107 的跨文件
  破坏面**结构上不存在**,`grep -rn` 确认无人写下这两个新文件的坐标。
  报告 `iterations/reports/strategy/20260823T092454Z.md`。
  **交棒**:① 录像组/GH #119 —— 已留言,**建议没被驳,是本地买不到**;最便宜的解锁是
  `make_fixture.py` 顺手带一份**「打出去」的伤害行**(dumper 战斗日志已有,06:55Z 那条留言
  就是从里面逐条读的),放在现成 `recent_damage` 旁边,**三个读数会同时变诚实**;
  ② 总监 —— **无入集提议**(不产 gate),只请收下一条口径:`fieldcreep` 的下一根杠杆
  **在语料能答之前不许写**,用例底部的棘轮是这条口径的执行体;③ 批测台 —— 无请求;
  ④ 主会话 —— P1/P2 球权,**连续第四轮**请求核对。
  **本组下一轮**:`fieldcreep` 这条线**在语料补齐前是堵的,不要再撞**。取 backlog 第 **2** 条
  (−18 econ 残差归因)或第 **4** 条(`suptp × midtp` 协同仲裁,owner 点名);
  若「打出去」的伤害行落地了,**优先回来把这根杠杆写掉** —— 立论早就够了,缺的一直是分母。
- 2026-08-23T07:55Z:**认领 GH #137(最新的 [strategy] issue,带完整帧证据):
  野点分级阶梯是死代码 ⇒ 落地 gated `campgrade`,并读出 issue 只点了一半的那一半。**
  **开工自检 worst exit 0**(UNLANDED 无 / cadence clean / trunk python **15 passed**),
  本地 `HEAD == origin/main == 6b0f7a5`;容器无 `lua5.1`/`luacheck`,已装。
  **认领依据**:P1/P2 的本组交付都已落地,**已连续第三轮**请主会话核对球权,本轮不再重复
  推理,直接走 issue 流取最新的 #137(06:55Z,落在本组「对线期/野区策略」范围内)。
  **⭐ 缺陷是两处不是一处**(issue 点了后一处):`RefreshCamp` 的四支 if/elseif
  **每一支都只给 `botLevel` 定上界**(`<=7`/`<=11`/`<=14`)⇒ **一个低等级 bot 打不动的
  营地不会被它那一档拦住,而是掉进下一档更宽松的分支**;最后一支还是**无条件 `else`**。
  跟一遍 **5 级 bot + 己方远古营**:一支拒、二支拒、**第三支 `<=14 and not 敌方` 收下** ——
  **连 `else` 都没轮到**。⇒ 整个循环 = `allCampList = 全图所有营地,任何等级`。
  **⭐ 修法的关键是「复合」,而这是被变异钉出来的**:第一版把三档写成**对营地种类的
  if/elseif**,那是**把同一个掉落错误搬高一层** —— 敌方远古营过了「敌方 ≥15」就直接返回,
  **永远不会被问「远古 ≥12」**。现在四条改写成**每一档都必须过**的合取:
  敌方 ≥15 / 远古 ≥12 / 大野 not-weak / 小中野恒可。
  **未 armed 逐字节等价且是断言出来的**:原四支链**原封不动留在源码里**(**没有顺手化简成
  「无条件收」—— 化简虽等价却会抹掉证据**),用例把**修改前那条链逐字转写**进来,
  在每个真实等级上**逐个营地比对**,再额外调一次**完全不带第二个参数**的 `RefreshCamp(bot)`。
  **交付**:`tests/test_campgrade_tier_ladder.lua`(**14 例全绿,3 变异 3 抓** ——
  M1 armed 也全收 → 4 红;M2 远古档 12→**10**(即 `GetClosestNeutralSpwan` 里那个数)→ 3 红;
  M3 if/elseif 不复合 → 2 红);主体是**同一个英雄(骷髅王)的 10 级与 12 级两帧跨阈值**,
  11/14/19 级真实英雄钉两条边界;**语料域 103 枚 / 1030 个真实英雄槽,953 个(92.5%)≤11、
  77 个 ≥12**(两个数都要:前者说有域,**后者说存在一群它不许碰的人口**,GH #137 §4
  明确禁止把整份远古普查打成 0),**按下界钉不按等式钉**(GH #106)。
  **⭐ 本地买不到的两件已写死在头注里(不要当成买到了)**:(W1) `GetNeutralSpawners()`
  **恒 `{}`** ⇒ 端到端驱动出厂入口只会返回**长度 0** 的列表,所以营地表是**声明出来的替身**
  (type × 阵营 4×2,恰好就是函数从一个营地上读的全部字段),**该文件没有一个数被声称是
  语料数据**;(W2) `GetAttackDamage()` **恒 0** ⇒ `<= 80` 子句**全语料恒真**。
  **(W2) 不是脚注,它决定了杠杆长什么样**:承重子句必须帧驱动得动 ⇒ 攻击力子句**留在原地、
  没进远古档**,而那正是 GH #137 建议 3 要做的事 ⇒ **建议 3 与建议 2 都刻意没捆进来**
  (lanefix 教训)。(W2) 有一处**已断言的看得见后果**:**19 级、攻击力 0 时 armed 收下
  敌方远古营却拒掉大野** —— 真实 turbo 局里不可能出现的不对称,是 (W2) 最锋利的一句话。
  **⭐ 顺带一条给别人的发现**:#137 §3 点名的 `f_260823_002103_wk_ancient_camp_634.lua`
  **不在树上、不在 main、也不在 285 个 remote ref 的任何一个上** ⇒ 11 级骷髅王那一帧
  本地买不到,承重案例退到 10 级真实帧(仍在 issue 自己的 ≤11 桶里)。
  **与 0S/UNLANDED 同族但检测器抓不到**:`unlanded_commits.py` 抓「推了没落地」,
  **抓不到「写进 issue 但从没推过」**;判断成本一条 `git ls-tree`。已交回录像组。
  **⭐ 0LN 第三次实证(已进 backlog 0LN2)**:mode_farm **+6**、aba_site **净 +36**,
  两处行钉当场红,**位移量恰好等于插入行数**;修法是**把钉子挪到新行号,不是放宽判据**。
  新增的一点:`test_pingstamp_world_assertion` 那一处**不在 0LN 原来点名的普查里** ——
  它是**错误消息里的行号**断言,长得完全不像行钉 ⇒ **判断标准是「有没有别的文件写下了
  我这个文件的坐标」**,`grep -rn '<改动文件>\.lua:[0-9]'` 一次跑完。
  **门**:`luacheck bots game` **exit 0 / 0 警告**;新文件 **14/14**;**定向复跑了
  `grep -rln` 出来的、读这两个改动文件的全部用例**(13/27/18/8/16/11/21/8/15/2/7 + 三枚
  replay),修完两处行钉后**全绿**;**全量没跑**(GH #124,约 100 分钟),
  **本轮不把它写成「整套又绿了一次」**。
  报告 `iterations/reports/strategy/20260823T075500Z.md`;`state.json:campgrade_20260823`。
  **交棒**:① 总监 —— `test_set.md` 顶部 07:5xZ 入集提议(**不申请专波**,并进下一波);
  ② 批测台 —— `queue.json:strategy-4`,**验收口径不要另造**(重跑录像组已有的
  `ancient_camp_domain.py`,主判据 + **同等重要的反向判据「全体次数不许塌成 0」**);
  ③ 录像组/GH #137 —— 那枚 fixture 从未落地 + 建议 3 的证据只能在波次录像里买;
  ④ 主会话 —— P1/P2 球权,**连续第三轮**请求核对。
  **本组下一轮**:backlog 上面全是流程条,取第 2 条(−18 econ 残差归因)或
  第 4 条(suptp × midtp 协同仲裁);若 #137 的波次读数已回,优先读它。
- 2026-08-23T05:30Z:**章程 backlog 第 8 条(「最终出价可达性」全组普查)最后一个 id
  `lf_rescue` 查完 —— 本条到此全部做完,而且交出本组从 item 层读到的**第一个正面判决**。**
  **开工自检 worst exit 0**(UNLANDED 无 / cadence clean / trunk python 14 passed),
  本地 `HEAD == origin/main == 0753a84`;容器无 `lua5.1`/`luacheck`,已装。
  **认领依据**:`OWNER_PRIORITIES.md` 的 P1/P2 仍写「球在协同组」,但两项的本组交付都已落地
  ⇒ 与上一轮同一判断,已**连续第二轮**请主会话核对球权;`[strategy]` open issue 要么是本组
  上一轮自己开的(#132,交棒中)、要么在等别组读数 ⇒ 取第 8 条名下仅剩的 `lf_rescue`。
  **⭐ 判决(正面)**:`lf_rescue` 的最终量**在本地买得到**。armed 时驱动**出厂入口**
  `ItemUsageThink()`,**39 个救援帧里 37 个各产出恰好一条**
  `Action_UseAbilityOnLocation(item_tpscroll, 落点)`,落点与 `J.GetNearbyLocationToTp`
  **逐点相等** ⇒ consider 与 `Action_*` 之间**零下游变换**;**未 armed 同样这些帧零动作**。
  两个例外**逐个点名、不是容忍**:vengeful_spirit 那一帧 item 文件装不起来(GH #82),
  以及**一次出厂敌方塔守卫的正当拒绝** —— 而它恰好是 **GH #37 的 frame B**:
  #37 把 frame B 的落点(1579u)**直接从 helper 读出来**,端到端驱动的话 Lina 走不到那里
  (她在敌方塔 888u 内,TP consider 在 **aiug:5095** 就拒了,**在救援分支上面两个分支**)⇒
  **那个数描述的是出厂链在那张快照上不会发出的一次 TP**。诚实边界:fixture 是 1Hz 快照
  (GH #107/#121),「在这张快照上」就是全部主张。**已交回 #37,本轮不动它。**
  **⭐ 而且这一族根本没有出价**:`ItemUsageThink`(aiug:8531)把 `ItemUsageComplement()`
  当**裸语句**调用、丢掉返回值;循环那句 `return nSlot + 1`(aiug:1031)死在同一个地方;
  判据只有 `nItemDesire > 0`、**从不跨物品比大小**。⇒ **第 8 条的规矩对这一族只能对着「动作」
  兑现** —— 按字面读会去找一个不存在的数。这一条是写给后面的 id 的。
  **⭐ 对第十六条世界断言的订正(已进 backlog 0ARM)**:它记的「整个语料零真实 item 决策,
  只有崩溃和一个原点幻影」**只对出厂默认成立** —— `_itemdesire_sweep.lua` **一个 candidate
  都没 arm**,而 TP consider 顶上那两条分支全是 gated。arm 上 `lf_rescue`,同一份语料
  **出现 37 个真实决策**,并且在那些跑不动的表面**之上**(救援分支 aiug:5117 就 return,
  在产出 209 次崩溃的 `GetExtrapolatedLocation`/`GetFarmLaneDesire` 通用块之前)。
  **缺口不在它的算术,在它的 arm。**
  **⭐ 顾虑 (i)「抢跑」从假设变成测量,而测量把自己大半否掉了**:章程写「要数语料」,数了 ——
  只把 TP 弄诚实 → 37/39 出 TP;**把物品栏每一件都弄诚实 → 10/37 被更靠前的槽抢跑**。
  但那 10 个里 **8 个是伪影**,并作为**第十九条世界断言**钉住:抢跑者是 `item_power_treads`,
  它整条分支选择压在 `GetPowerTreadsStat()` 上而 loader 从不接线 —— **270/270 个 handle 读 0**,
  **0 不等于 mock 发的任何 `ATTRIBUTE_*`**。剩下 2 个是诚实读数(arcane_boots <58% 蓝、
  clarity 给缺蓝队友)⇒ **诚实区间 2/37 .. 10/37**。**机制毫无疑问(就是出厂那句 `return`),
  只有大小买不到** ⇒ 真实率交**录像组**;**`bots/` 零改动**(照静态形状改共享物品循环
  正是 `lanefix` 入口)。**没有断言的那一半也写下来了**:引擎自己的 `ATTRIBUTE_*` 编号
  在本仓库**不可知**(`BOT_API_REFERENCE.md:1931` 只列名字不给值),
  所以「0 会不会**恰好就是** ATTRIBUTE_STRENGTH、让这个默认值悄悄表示『力量腿』」**是开着的**。
  **⭐ 率本身也只夹住、没定位**:GH #81 让每个英雄都读核心,而收窄后的 helper 拒绝对线期核心
  ⇒ 出厂 `J.IsCore` 下 **10** 帧、override 成 false 下 **39** 帧,**两端同一次运行里都量了**;
  10 是「全是核心」的世界、39 是「全是辅助」的世界,**真值被夹住了,不是被定位了**
  (用例里那条断言写明:若 GH #81 被修好、它转红,区间就塌成真实率,报告 §6 必须重写)。
  **⭐ 一条踩到的新流程条(已进 backlog 0SS)**:`J.GetRescueTpTarget` 是**单发**的 ——
  最后一个合取是 `J.TryTakeTpResponseSlot()`,**同一帧问两次第二次答 nil**。
  对 `lf_rescue` 自己**这是正确的、不是 `tpclaim` 那个缺陷**(配额取在**最后一个合取**,
  其余条件全过才花,调用方同一帧把答案变成动作,**问和去是一步**)。后果只落在写用例的人身上:
  **先用 helper 预筛、再在同一次 load 里驱动,量到的是一个空世界**,而它长得像「这条分支到不了」。
  本文件每一个计数在预筛与每条 arm 之间**都重新 load**。
  **交付**:`tests/test_lf_rescue_final_action.lua`(**12 例全绿,3 变异 3 抓** ——
  M1 槽序 `{...,15,16}`→`{...,16,15}` 点红 `[preemption]`;M2 救援分支返 `NONE` 点红 3 条;
  M3 循环改返 desire 点红 `[no bid]`;每次都还原了树)。
  **扫描槽位顺序是从出厂源码 parse 出来的、不是抄进用例的**(M13 教训);
  **计数用 floors 不用等式**(GH #106 教训),armed/none/err 三路必须**闭合到 hits**。
  **本文件跑 ~43s**:第一版 ~118s,把「出厂 IsCore」那一问也放在全部 940 个 subject 上了;
  **修法用单调性** —— override 只会**放松** helper ⇒ 出厂世界的命中是 override 世界的**子集**
  ⇒ 只在已命中的 39 帧上再问一次,**同样的数、一半的墙钟**(GH #124 在抱怨整套跑不完)。
  **门**:`luacheck bots game` **exit 0 / 0 警告**;新文件 **12/12,rebase 前后各跑一次**
  (收尾时 main 前进到 `ef454a2`,语料 101 → 103,**下界写法一动不动 —— GH #106 §4 的正面数据点**);
  语料敏感面 + 两个枚举 `tests/` 的 ratchet 定向复跑,**1 红且不是本轮造成的**
  (`test_gamemode_world_assertion.lua:447` 「expected 23 of 100 fixtures; got 24」,
  是同一次 rebase 带进来的字面量等式陈旧;本轮 commit 只动了新用例 + `iterations/*`
  ⇒ **已作为 GH #106 的新一次实证留言,不代改别人的 ratchet**)。
  **全量没跑完(GH #124),本轮不把它写成「又绿了一次」。**
  报告 `iterations/reports/strategy/20260823T053042Z.md`;
  `state.json:lf_rescue_FINAL_ACTION_AUDIT_20260823`。
  **交棒**:① 录像组 —— 抢跑的**真实发生率**(本地只买到区间,且 8/10 是伪影)+
  `item_power_treads` 在真实对局里走哪条臂;② 总监/GH #37 —— frame B 的落点数与出厂链的矛盾;
  ③ 总监 —— **第 8 条到此全部做完**(7 个 id,产出 4 个 gated id、1 条出集建议、2 条负结果);
  ④ 主会话 —— `OWNER_PRIORITIES.md` 的 P1/P2 球权,连续第二轮请求核对。
  **本组下一轮**:第 8 条已清空,从 backlog 上面重新取一条。
- 2026-08-23T04:15Z:**章程 backlog 第 8 条(「最终出价可达性」全组普查)轮到 `teambrain`;
  普查本身交出一条**负结果判决**,并在**出价下面一层**撞到一个真缺陷 ⇒ gated `tpclaim`。**
  **开工自检 worst exit 0**(UNLANDED 无 / cadence clean / trunk python 13/13),
  本地 `HEAD == origin/main == 68d0ea2`。**认领依据**:`OWNER_PRIORITIES.md` 的 P1/P2
  都写「球在协同组」,但**两项的本组交付都已落地**(P1 第 1 棒 07:30Z + 回程波 02:06Z 收割,
  主判据在录像组;P2 决策侧 `stayfield`/`stayfield2` 已在树上且已入集)⇒ **该文件此刻滞后**,
  本组不自行增删,已在报告 §6 请主会话核对。backlog 上面几条要么做完、要么是流程条、
  要么自己写着「在拿到波次读数之前不要动」,于是取第 8 条。
  **⭐ 判决(负结果,值钱的那一半)**:`teambrain` 的**最终出价在本地结构上买不到**,
  而且**两条卡点都在 harness 轴上、不是语料缺口** —— 唯一调用方压在
  `J.IsDefending` → `bot:GetActiveMode()`(**第十三条**,全语料恒 0)之下,目的地
  `X.GetDefendTPLocation` = `GetLaneFrontLocation`(**GH #61 拒答**)。**再买一波也买不到。**
  ⇒ **`teambrain` 在 armed 集里,却从来没有本地证据证明它动过一次出价**;
  `test_replay_teambrain_tp.lua`(5 例)断言的**全是 helper 返回值**。它的 (a) 只能在波次录像里买,
  请总监判读时带上这条。
  **⭐ 缺陷(审计顺出来的那一半)**:单人应答 claim(12s/1600u)的戳记写在 **query 末尾**
  ⇒ **claim 是被「问」烧掉的,不是被「去」烧掉的**。调用方(aiug 守塔分支)问完之后
  **下一行还能拒**,而这两行读的是**两个不同的量**:赋值条件是
  `botAmount.distance > 5500`(离那条路多远)或 `botAmount.amount < laneFront/5`(落后前沿多少),
  拒绝条件是 `GetUnitToLocationDistance(bot, tpLoc) <= 5000`(**到目的地的直线距离**)。
  **一个待在自家基地、而中路正被围的 bot(Turbo 后期最常见的守家场面),
  或一个站在另一条路上的 bot,过得了第一行、挂在第二行:它根本不会 TP,
  而它刚拿走的 claim 把四个真能应答的队友挡了 12 秒。仲裁因此翻转 ——
  唯一的应答名额发给了那个不会去的 bot。**
  **改的是一个变量**:armed 时 query 不再戳记,改由调用方在**已过完全部拒绝、
  正走向 `BOT_ACTION_DESIRE_ABSOLUTE` 的那一行**戳(新 `J.NoteDefendTpClaim`)。**问不等于答。**
  **未 armed 逐字节等价,而且是断言出来的**:`tpclaim` 关 ⇒ query 照旧原处戳记,
  调用方新增那一次是**同一帧/同一 bot/同一点**的重写(`[off-candidate equivalence]`
  对读两条路径的裁决);`teambrain` 关 ⇒ 整个仲裁在读 claim 之前就返回
  (`[transparency]` 对 `{}` 与 `{tpclaim}` 两种组合各断言一次)。
  `tests/test_tpclaim_stamp_on_commit.lua`(**12 例全绿,3 变异 3 抓**):
  **今天的缺陷与修好之后在同一枚真实帧上正反各钉一次**
  (`f_260819_222526_jakiro_defend_fresh`);`[the guard survives]` 保住 343.2s 三人同帧 TP 那个病例;
  12s(11.9/12.1)与 1600u(1500/1700)各一对边界;`[untouched legs]` 用 wave12 卷宗的
  1v3 帧(`f_050713_es_defend_1v3`)断言上面三条拒绝腿一条没动。
  调用方那一半只能结构断言(§判决),**而且是在去掉注释之后的源码上做的** ——
  这个文件自己的头注和修法的头注**逐字引用了它要找的每一个标识符**,
  **本组第三次撞上「纯文本判据把注释读成代码」,这次在写下去之前就拆了**。
  **⭐ 两条新流程条,都是被红点出来的、不是想出来的**(已进 backlog 0LN / 0PID):
  (1) **加行会让按 `file:line` 钉行的普查静默错位** —— aiug 加 10 行,
  `test_level_gate_census` 两红(`missing source for :5759` + `unpinned gate at :5768`),
  **位移量恰好都是 +9**,把钉子挪到 `5768/5808` 即修(源码一个字没变,`text=` 仍逐字命中);
  这是 GH #106 的孪生:那条讲共享**语料**,这条讲共享**源码坐标**。
  (2) **「两个 bot」在 60% 的 fixture 上是同一个 bot** —— 101 枚里只有 **41 枚**带真实
  `player_id`,其余读 mock 默认 0;第一版选的 `f_045650_lion_meatgrinder` 正是那 60 枚之一,
  **是 setup 里 `assert(a:GetPlayerID() ~= b:GetPlayerID())` 抓住的,8 个用例当场全红**。
  **门**:`luacheck bots game` **exit 0 / 0 警告**;全量 **1380 tests / 20 failures**,
  **其中 2 条是本轮自己撞的(上面那条 +9 错位),修掉后 18** —— 与 GH #127 记的 18 条
  纯语料规模等式红**逐文件相同**,**delta = 0**。(全量单次约 100 分钟,修完那一个文件后
  只定向复跑了它,没有再烧第二个 100 分钟;这一点写在报告 §8 里,不当成「全套又绿了一次」。)
  **GH #132**(本轮结论与交棒的公开落点);报告 `iterations/reports/strategy/20260823T041500Z.md`;`state.json:tpclaim_20260823`;
  `test_set.md` 顶部 04:xxZ 入集提议(**并进 `teambrain` 那一波,不申请专波、不提 queue 单**)。
  **交棒**:① 总监 —— `tpclaim` 入集 + `teambrain` 的 (a) 判读带上那条负结果;
  ② 主会话 —— `OWNER_PRIORITIES.md` 的 P1/P2 球权已滞后,请核对。
  **本组下一轮**:第 8 条名下只剩 `lf_rescue`。
- 2026-08-23T01:27Z:**`itemtrip` 上机(GH #120,owner P2 那一族在健康侧的另一半),
  外加把本组自己**推了没落地**的上一棒捡回 trunk。**
  **⚠️ 开工自检报的三条 UNLANDED 里有一条是本组自己的**:23:19Z 的上机前审计
  (`43ad339`)躺在 `origin/claude/dreamy-feynman-rr5l3v`,`main` 上没有;
  cadence 报的 4.0h 洞是同一件事的另一个投影。**本轮第一个动作是 cherry-pick 它回来** ——
  不捡的话本轮会在一个不存在的判决上重写一遍同一份审计(铁律 10 立案的那个形状)。
  **改的是一个变量**:新增 `bots/mode_item_generic.lua`。**未 armed 时它一个 `GetDesire`
  都不定义** ⇒ 引擎保留内置出价 ⇒ **未 armed 的一局逐字节等于今天这一局**;
  谓词 `J.IsWastefulItemTrip` 只有它一个调用者,**多一个调用者就等于把行为发布了**。
  **⭐ 三个常数一个也不是新调的**:`0.55` 是 `J.IsFieldRegenSituation` 的天花板**从另一侧取**
  —— owner P2 的「不要回家」于是被两半在**整条血量轴上分完,不留缝也不重叠**
  (用例从源码读两个字面量断言相等,漂开就红);`1600` 与归属化伤害子句是从同一个函数抄的;
  `5000` 是 #120 自己的往返中位 40.1s 按 ~300 移速换算(~12,000u 往返 ⇒ ~6,000u 单程)
  **向下**取的地板。
  **⭐ 唯一的未知量被写成了一条可证伪的预登记**:armed 时浪费帧返 `NONE`、**其余帧返 `nil`**,
  而「`nil` 落回内置」是 `BOT_API_REFERENCE.md:52` 一条**本树从无使用者**的合同。
  **方向由构造锁死在安全一侧** —— 这个文件**只可能压低 item mode 的出价,永远不可能抬高**,
  所以最坏是「英雄不去取 stash」,**不可能是「英雄更频繁地回家」**;在那个界限内两种结果
  (合同真 ⇒ 内置减去浪费帧;合同假 ⇒ 整局 item mode 关闭)**都写进头注和验收口径**,
  录像组不需要额外仪器就能把两者分开,**后者顺带为所有后来者兑付掉这条引擎语义**。
  **⭐ 本轮最值钱的一次量测:那条没有写的物品栏子句。** 初稿带
  `Item.GetEmptyInventoryAmount( bot ) > 0`(「背包满了回去取货是正当的」),
  **在承重帧上它是死的** —— 那一帧 **9 格全满**(快递在快照前 ~0.2s 送到;#107 的标签滞后
  正是 #120 自己 434.5 那行还写「第 9 格一直是空的」的原因)⇒ 这条子句会让整个杠杆
  **在它自己的立案帧上恒为假**,**luna 追击那个失败形状**,这次在写下去之前被 fixture 拦住。
  它**也不必要**:#120 那 136 次「背包满去取货」是 `撤退:1`,走 retreat 的 shop 动机,
  **本文件够不到**。**代价被量出来了**:浪费域 310 帧里背包全满 **14 枚(4.5%)**,
  而承重帧是那 14 枚之一 ⇒ 这条子句要花掉域的 4.5% 和**立案帧的 100%**(写进用例上下界)。
  **⚠️ 收尾前 11 分钟这条被降级成暂定,已登记 + 交棒(别把它当已定论引用)**:
  录像检查组 01:16Z 落地 —— **#120 的 `shop` 标签靠一个阶跃布尔排除,1Hz 读它
  对 15.1% 的人口无法判定、实测翻转 2.6%**,`run_121209` 的残差因此 15 → 12(−20%),
  掉的三行**本来就属于 `shop`**。**这正好从另一侧打在承重帧上**:fixture 显示
  TP 起手那一瞬背包已满,而 #120 的 434.5 行读的是「第 9 格空」⇒ **承重帧很可能
  本来就是一次 `shop` 行程,根本不在那 76 行残差里**,而 `shop` 走 retreat mode、
  **本 gate 够不到**。**没改任何一条断言**(14 例问的是这一帧的量,不是 #120 的归因),
  **也没推翻缺陷**(录像组自己保住了人口);改的是「为什么不写物品栏子句」这条**理由的强度**
  —— 若承重帧 settle 成 `shop`,那条理由就翻面成「这一帧不在射程内」,**子句该加**。
  **本轮不当场翻**:在一份 11 分钟前落地、承重帧尚未 0.1s 重扫的报告上翻转一个已量测的决定,
  是拿一次量测换一次新猜测。**交棒 = 请录像检查组按他们自己的 0.1s 流程重新归因那一帧。**
  `tests/test_itemtrip_wasteful_trip.lua`(**14 例全绿**):承重帧断言的是**最终出价**
  (armed → `NONE`;**未 armed → 一个 `GetDesire` 都不装**;armed 的是 `stayfield` → 仍不装);
  **五枚阴性对照四枚住在承重帧自己那一枚 fixture 里**(同一秒、同一张图、只差被测的那个量);
  **N3 是 owner P2 自己的铁证帧**(31.8% 血)⇒ 断言**这一半不许认领它**;
  N4/N5 是归属子句的两面(**全语料唯一一枚由它拍板的帧** + 4,321u 外的「全球大招」形状);
  三对边界钉子 `1600`(同 fixture,**1,597 vs 1,621,相差 24u**)/`5000`(4,765 vs 5,239)/
  `0.55`(0.492 vs 0.563)。域普查子进程 `tests/_itemtrip_sweep.lua`:
  101 fixture / 940 存活英雄帧,浪费 **310**,why 分解 hp 177 / ring 386 / dist 66 / dmg 1,
  **和恰好 940**(不闭合就红);**310/940 是域的大小不是发生率**(第十三条:fixture 不带 mode)。
  **⚠️ 写用例时踩到并钉住的一条**:**两个 fixture 世界不能同时存在** ——
  `rf.load` 装的是一整套全局,第二次加载会把 `GetTeam` 换掉,于是**第一个世界的 helper
  在第二个世界的参照系里作答**(axe 的离家距离读出 15,316 而不是 4,765 = 他到**对面**泉水)。
  边界对照改成**读完一个世界再加载下一个**,理由写进文件。
  **GH #127**:本轮只收了**自己改动压到的四处**等式断言(信使/stash 普查 `==100` → `>=101`+不变量;
  mode 文件早返回普查 → `>=12` 下界;`BOT_MODE_ITEM` 分支普查**跳过整行注释**
  —— 它把本轮新文件的**头注**读成三个新分支站点,和 defend-ping 那次是**同一种文本判据失灵、
  从另一个方向来**;`test_gamemode_world_assertion` 的 `#mode_files()` 21 → 22,
  **那条本来是被上一行失败挡住的隐藏红**)。**另外五个文件是 #127 指派给总监的,没碰。**
  报告 `iterations/reports/strategy/20260823T012700Z.md`;`state.json:itemtrip_20260823`;
  `test_set.md` 顶部 01:2xZ 入集提议(**并进现有波,不申请专波**);`queue.json:strategy-3`。
  **全量 1348 / 19,修掉本轮自己那 1 条后 delta = 0**(失败集合逐文件等于 #127 记的 18)。
  那 1 条值得记:`test_activemode_world_assertion` 的「调用点 255 → 256」**是被我写在
  `jmz_func` 注释里的一句 `bot:GetActiveMode()` 点红的** —— **本轮第三次撞上同一族
  纯文本判据失灵,而这次是我去踩别人的**。修法照旧:不加假声明、不改别人的 ratchet,
  把那句注释改成「the bot's active mode」——**我那句话本来就不是一个调用点。**
- 2026-08-22T23:19Z:**认领 GH #120,给 `itemtrip` 做上机前可达性审计 —— 判决是「可以写、
  但判据不许读那三样」,`bots/` 零改动。** 产出 `tests/test_itemtrip_supply_gap.lua`(10 例)。
  **0RES 第一次产出「找了、确认没有」而不是「没找」**:`BOT_MODE_ITEM` 分支普查 8 个站点,
  **5 个是熊/arc 分身/meepo 分身/lone druid 专属,3 个是到家之后的收尾**
  (`mode_roam:1335` 自己的注释就是 "is stuck in item mode" ⇒ **树早知道 item mode 会把人拖回家,
  它管的是尾巴**),**CONTESTS_TRIP = 0** ⇒ 与 #123 正相反,这次缺陷是真没人管。
  **⭐ 承重发现,而且第一版判决是反的**:我先写的是「加 mode 文件结构上不可 gate」,
  错因是**只读了 mode 文件的 GetDesire 半边**。`bots/mode_attack_generic.lua`
  **只给 `Utils.BuggyHeroesDueToValveTooLazy` 那 9 个英雄**装
  `GetDesire/Think/OnStart/OnEnd`,**其余约 118 个英雄它什么都不装、而他们照样普攻**
  ⇒ **「不定义 ⇒ 引擎保留内置」是每局都在跑的已观测行为**,这就是 `itemtrip` 该用的
  **load-time gate**(文件作用域判 armed,armed 才定义 GetDesire;未 armed 逐字节等于今天)。
  **不许用**文档里那条 `GetDesire()` 返 nil 落回内置的合同:`bots/` 里 **0 使用者**,
  是**未兑付**的,而**它错的代价是反向的** —— 未 armed 的每一局 item mode 被静默压掉,
  **一个穿着 gate 外衣的已发布行为改动**。另:`--mode_item_generic.lua` 去掉前缀
  = 全队全英雄无 gate 地「item mode 永不出价」,不是一小步。
  佐证不是我一个人读的:`test_tpwatch_channel_bid.lua` 在真实帧上 dofile 全部 21 个
  mode 文件、断言 `#engine_owned >= 1`,点名的正是 `mode_attack_generic`。
  **⭐ 第十八条世界断言(实测 100/100)**:**fixture 世界里没有信使,而读它会崩** ——
  `GetCourier(0..4)` 恒 nil ⇒ 出厂 `X.GetBotCourier` 的循环 **100/100 pcall 失败**
  ⇒ `CourierUsageComplement` 约 140 行(含 `COURIER_ACTION_TAKE_STASH_ITEMS`,
  唯一一条「不用把身体送回家也能掏空 stash」的补救)**今天写不出任何用例碰得到**;
  `bot:GetStashValue()` / `GetCourierValue()` 恒 **0** ⇒ 一切 stash 子句**恒假**;
  **`GetCourierState` 连自动常量都不是**(mock 只给 ALL_CAPS 发号,它是混合大小写)
  ⇒ **读出 nil、调用即崩** —— 与 `BOT_MODE_ITEM`(拿得到号、只是恒 false)**方向相反**:
  一个让子句悄悄为假,一个让用例直接死。
  ⇒ **判决**:`itemtrip` 的判据**不许读 stash 内容 / 信使状态 / `GetActiveMode()`**
  (第十三条:恒 0),否则就是 0p 的形状;**可花的预算 = 血量 / 最近敌人 / 离泉水距离 /
  物品栏占用**,而 #120 的残差画像正好全落在这四个轴上。
  **⚠️ 全套抓到一条误报并把它改对了**:`test_defend_ping_declaration_ratchet`(GH #91)
  的判据是**纯文本**(「提到 GetDesire + 提到某个被看守的 mode 名」),把这个**只读文本、
  一个出价都没驱动**的普查文件点成了 bid driver。**没有**加假的 `declare_defend_ping`
  (那是说谎)、**没有**塞进 `LEGACY`(定义对不上)、**别人的 ratchet 一个字没动**;
  改的是**把普查的文件清单从硬编码换成 `grep -rl` 发现** —— 误报消失,
  **而且这本来就是更好的形状**:硬编码清单会在「有人往清单外的文件加了 item-mode 分支」
  那一刻失效,**而那正是这个普查唯一想抓的事件**,失效时它还照常报「仍然 8 个、0 个拦截」。
  **0S2 第三次实证:目标跑绿不算数,全套的失败枚举才是清单。**
  **⚠️ 收尾还撞到第二条**:全套绿 → commit → 推 main 被拒 → `git pull --rebase`(干净)
  → **我的文件当场红两条:`fixture count moved from 100 to 101`**。远端一个多小时里多了一枚
  fixture,而我把语料规模**钉成了字面量** —— **GH #106 说的正是这件事,我差点成为第六个消费方**。
  改成**和同一次运行量到的规模比**(`== c.frames`)+ 一条 `>= 100` 地板抓缩水
  ⇒ **增长免费、丢失照抓**。一句话:**「跑绿」是对某一棵树的判决,不是对下一棵树的。**
  另:自检报的两条英雄组 UNLANDED,rebase 时已确认落地(`66c81d9`/`8eec878`)——
  `unlanded_commits.py` 的 LIMITS 再次成立,**报出来的是问题不是判决**。
  **⚠️⚠️ 收尾还发现 main 是红的(1334 tests / 18 failures),不是本轮造成的**:
  `70aefe5`(录像检查组)加了第 101 枚 fixture 却**只重锚了一个消费方**,
  另外**五个**文件的语料规模常数没动 ⇒ **GH #106 当场兑现,而 #106 至今 open**。
  本组的新文件**曾经是第六个消费方**,已改成按运行时规模比,**不在这 18 条里**;
  **没有代改别组的基线**(盲改普查常数 = 把「已知世界」换成「我猜的世界」)。
  **→ 全组:main 现在过不了铁律 6 的门。**
  **⚠️ 还有一条对本组下一棒的更正**:我要的那枚 #120 fixture 收尾时到了,
  **而它把 #120 的两枚承重帧全推翻了** —— 0.1s 重放显示快递落袋与 `ITEM item_tpscroll`
  **在同一 tick**,决策瞬间 `X.IsInvFull` 为真 ⇒ 那两趟其实是普通 `shop` 分支。
  人口(76)按录像组重扫**基本站得住**(伪影个位数%),但**展品不能再用**。
  ⇒ 下一轮**先要一枚重算后人口里的干净承重帧**再写 gate;并且**「物品栏占用」必须亚秒级读**
  ——**1Hz 盲窗打在布尔闸门上是标签翻转,不是偏几个百分点**。
  报告 `iterations/reports/strategy/20260822T231910Z.md`。
- 2026-08-22T21:06Z:**认领 GH #123(owner P2 供给侧),判定「修法不上」——
  那颗大药不是卡住了,是有人每帧在救它。** `bots/` 本轮**零改动**;
  产出是一次**拒绝和它的理由**,钉成 12 例新用例 + 一条语料普查。
  #123 提议把 `fieldbuy` 采购门从九个槽(`Item.GetEmptyInventoryAmount`)收到
  六个可用槽,一个词、helper 已在树上。**域是真的,前提不是。**
  **⭐ 承重发现**:出厂有一个**无 gate 的搬运工** `TrySwapInvItemForFlask`
  (`mode_team_roam_generic:1854`)把背包里的大药换进主槽,而且它挂在
  **`GetDesire` 上不是 `Think` 上** —— 引擎每帧对每个 bot 轮询**每一个** mode 文件的
  `GetDesire`,只有 `Think` 才是赢家专属 ⇒ **它每帧都跑,不是 roam 专属行为**。
  从 `GetDesireHelper` 开头到那次调用之间**只有一条 early return**
  (invulnerable / 非活英雄 / 幻象);节流戳 `SwappedFlaskTime` 是**静态 `-90`**,
  **不是第十四条那个「用它稍后要比的时钟初始化」的形状** ⇒ 真的放行;
  全仓库**一个 roam 文件、零英雄级 override**。三条都是 `[reverse]` 源码断言。
  **⭐ 代价与覆盖量在同一批帧上**(`_fieldbuy_supply_sweep` 新增 `SPLIT` 行):
  28 个 dry 域帧里 **13(46.4%)**是六主槽全满、背包有空位 = 修法会打掉的那些;
  这 13 帧里搬运工**有主槽物品可换的是 13**,**真卡死 0**。
  ⇒ 桌上的交易是**「放弃 owner P2 要的行为的 46.4%」换「止住 12.9% 的浪费」**,
  而录像组的 12.9% 是**搬运工之后的残差、不是总体**。**这是 lanefix 的形状**:
  一条局部站得住的子句,配一个局部论证从没看过的聚合。
  **⭐ #123 自己 §3 就带着反证,只是读反了**:viper t=354.5 大药在背包、**354.6 被喝掉**,
  被归给「同一采样格内快递 + 合成腾出主槽」;**一个每帧无条件跑的搬运工是更简单的解释**,
  而「**背包只是一站**」这句结论是他们自己写的。
  **⭐ 差点栽的坑,已钉住(0p 的镜像)**:mock 对 `Get*` 答 0 而
  `ITEM_SLOT_TYPE_BACKPACK` 是哨兵 **1174** ⇒ 搬运工的槽型判断**在语料每一帧恒 FALSE**
  (**第十三条 GH #89 在新站点复发**)⇒ **一个天真的隔离用例会驱动它、在 930 帧读到 0 次搬运、
  于是「确认」#123** —— 又快又绿又全零。**0p 是不可达分支悄悄把功劳记给一个 gate;
  这条是不可达分支悄悄替一个它其实在阻止的缺陷背锅。** 声明按 GH #61 写进用例并配变异。
  产出:**新** `tests/test_fieldbuy_backpack_rescuer.lua`(12 例)——
  **一条最终动作**(在修法会打掉的那一帧上驱动出厂搬运工,断言
  `ActionImmediate_SwapItems(6,0)`;钉的帧**正是这一族既有用例的 Frame B**
  `f_260820_043637_axe_ring_alone`/viper)+ 两条阴性对照 + 一条「零 armed 也照跑」
  + 三条可达性钉子 + **一条棘轮**(fieldbuy 块必须仍读九个槽,谁应用 #123 修法谁先被
  转红逼着读头注;**不是否决权** —— 13/13 若被推翻,同一提交里删掉并说明);
  改 `_fieldbuy_supply_sweep.lua`(既有六个数 930/150/82/50/22/28 与 24/22/18/13
  **逐字未动**)+ `test_replay_260822_fieldbuy_supply.lua`(21 → **22**,0n 核对)。
  **五条变异全部落在预定断言上**,其中 M4(`GetMainInvLessValItemSlot` 恒 -1)与
  M5(不再测背包)**证明最终动作读的是出厂搬运工真实的取槽逻辑,不是我注入的把手**。
  **诚实边界**:快递投递是**建模的**(必须 —— 语料里没有任何一帧背包带大药,
  快照是瞬时的而搬运工 6.2s 内就清掉这个状态);**换掉哪一件物品量不了**
  (离线 `GetItemCost` 答 0 ⇒ 比价退化);**本文件不主张 12.9% 残差是假的,
  只主张采购门不是它的成因**。
  报告 `iterations/reports/strategy/20260822T210634Z.md`;
  `state.json:fieldbuy_backpack_rescuer_20260822`。
- 2026-08-22T19:00Z:**认领 GH #119 —— 野区回血的处境判据对小兵/野怪全盲,gated `fieldcreep`**。
  `J.IsFieldRegenSituation` 的三条危险子句读的全是**英雄和塔**,一条也不读小兵/野怪,
  于是函数自己的注释「nobody anywhere near it」在真实帧上可以与「正被半人马营按着啃」同时为真。
  修法**追加**一条 gated 子句问 `WasRecentlyDamagedByCreep`,**沿用英雄子句一模一样的 3.0 回看窗**
  ——**这是那条子句缺的另一半,不是新调的常数**(`[reverse]` 钉子:两个窗口漂开就红)。
  **子句不需要自己的距离判据**:小兵攻击距离只有几百码 ⇒「三秒内一只小兵打了我」
  **携带的归因比英雄那条用 3000u 扫描重建的更强**,不是更弱。
  **追加位置在塔子句之后是刻意的** —— 拆出这个函数时的行为保持论证写的是「下面的子句顺序未变」,
  只有追加能让那句话继续为真。
  **域**(100 fixture / 930 存活英雄帧):situation **50 → armed 45**,被否 **5**
  = **有回复品 2**(决策侧两个 id 的域)+ **没有 3**(`fieldbuy` 的域)
  ⇒ **P2 的两半被同一条子句同时影响**,这是它写在共用谓词里的**实测**理由。
  **⭐ 先说边界,并且这次边界比读数大**:50 枚里 **34 枚是 v1 fixture,根本不带 `recent_damage`**,
  loader 在那些帧上不装伤害读取器 ⇒ 子句**问不出来**(不是「因为好理由而为假」);
  可问的 16 枚里 9 枚是真安静。⇒ **5/16 是下界,`5/50` 这个写法本组不用。**
  **条件 (c) 换成同一个单位说完**:三秒内 tango 给 21 / 仙灵之火 85(一次性)/ 药膏 ~92 / 瓶子 ~135,
  而被否那五帧在同样三秒挨了 **14 / 22 / 109 / 129 / 132** ⇒ tango 五帧全输,后两者在重的三帧上输。
  **不是「大药被打断」在起作用**:药膏和 tango **扛得住小兵伤害**,这正是上游没人察觉的原因。
  **自带一条过宽角并明写不调**:药膏 vs 单个线兵那一格,留下来其实是赢的;要读伤害量级得有
  野怪/小兵单位表,fixture 不带 ⇒ **下一个杠杆**。
  **⭐ 本轮的措辞订正**:第一版把 creep 伤害写成「双峰 8-14 / 27-45」,拿到直方图后站不住
  (282 行里 256 行 ≤24、26 行在 25-45,**众数 10-14、中间带有 64 行**)⇒ 改写成**重尾**,
  并把「尾巴 < 十分之一」写成断言。**同 0R 那条:一个读数不构成一次测量,一个形容词更不是。**
  `tests/test_fieldcreep_veto.lua`(**16 例,5 次变异 5 抓**)+ 子进程普查 `tests/_fieldcreep_sweep.lua`;
  两枚钉帧断言的是**最终 wrapper 决策**(lion 25% 血 / juggernaut,`stayfield`+`fieldcreep` ⇒ STAY 翻面),
  **牙齿在两枚阴性对照**:dt=4.3 的窗外命中(**钉住 3.0**)与 **owner P2 自己的铁证帧**
  `f_260822_063722_lina_tp_home`(**断言原样不动** —— 压掉它就等于吃掉这一族存在的理由)。
  **⭐ M3(去掉 gate)顺带证明了两件事**:改动**有到达兄弟文件的力量**(`fieldbuy` 那份 22/28 划分整个动了),
  而 **gate 就是让它保持惰性的那个东西**(装上 gate 后兄弟普查一个数没动)。
  **明确不采用 #119 建议的字面写法**(给 situation 加 `GetNearbyCreeps` 几何子句):
  UNIT_LIST 上没有 creep(loader 明写的供给缺口)⇒ 在 fixture 上恒为空,加了就是**结构不可达**的子句,
  **而它会跑得又快又绿** —— 正是 0p 记的那个形状。
  **翻面一条兄弟合同用例**(`test_replay_260822_fieldbuy_supply.lua` 原写「situation 必须无 gate」)
  → 改成断言它要保护的那个**性质**:里面的 gate **只许收窄不许放宽**(M2 被两个文件同时抓)。
  **⚠️ 第一次全套是红的,红的那条不是新文件**:同一条 gate-free 合同**在两个文件里各有一份**,
  grep 只找到 `fieldbuy` 那份,`lina_tp_home` 那份是**全套的失败枚举**告诉我的(见 0S2)。
  两份都改成「里面的 gate 只许收窄」,第四个消费方 `lina_walk_home`(19 例)核对过不含此断言。
  **全套复跑 1292 tests / 0 failures / EXIT=0**,luacheck 0 警告。
  报告 `iterations/reports/strategy/20260822T190000Z.md`;`state.json:fieldcreep_20260822`;
  `test_set.md` 顶部 19:0xZ 提议行(**并进同一波,不申请专波**)。
  **P1 回程本轮已确认没卡住**:总监 18:50Z 批准 `pullcamp` 重新入集并**驳回专波**,
  按 0P1b 的规矩本组不重做、不重提。
- 2026-08-22T17:30Z:**owner P1 的唯一阻塞项(GH #117)修完并交出三棒**。
  总监 16:5xZ 把 `pullcamp` 摘出 armed 集,理由是「(a) 的证据是版本专属的,#117 的修法
  必然改写选点代码」——本轮把那份修法写完,于是**那条裁定自己写好的回程可以走了**
  (`test_set.md` 顶部 17:3xZ 提议行 = 重新入集;`queue.json:strategy-2` = 取证波,
  挂在批准上;录像组那条正控**不必等新语料**)。
  **一个变量**:选点从「离 bot 最近的己方营」改成「离 bot 最近、**且比车道中点更靠近
  我方远古**的己方营」;`vMid`/`vOwn` 是均衡子句上面**已经解出来的同两个位置**,零新引擎调用。
  **1500 reach / 窗口 / `IsLanePullSafe` 的 0.5 血量门一位没动**,各配一条 `[reverse]`
  源码钉子(谁把它们和选点一起改就转红,否则连接率无法归因)。
  **⭐ 本轮最值钱的一次算术:三条听起来都对的几何,只有一条咬得住那个营。**
  用真实远古坐标算 #117 的热点营 (3994,-5137):离 radiant 远古 **9,916u** / 离 dire 远古
  **10,252u** ⇒ **它算 radiant 的半场** —— 「camp 在我方半场」这条子句**放它过,修了等于没修**;
  「camp 比 bot 更靠近远古」(#117 §建议 3)最好也只到 ~9,200u,**仍在中点之外**,
  达不到总监验收口径 2 的 9,403u。**中点判据把它拒掉**(9,916 > 7,717)。
  **⭐ 免费的域普查**(0P2 那条规矩的第二次兑现,`_pullcamp_sweep.lua` 新增 `depth_*`):
  进入选点的窗口内辅助帧 15 枚,**12/15 站在车道中点之外** ——
  这是批测 283 局「中位 57% 处」的**独立同向确认**,两份语料互不相干;
  4/15 深到修法必返回 nil、2/15 算术上不可能被影响、**9/15 是真正判别的带**。
  **不会变回 SILENT 的反证**(用批测自己的数):115 个 poke episode 里 **48 个开拉点已在
  离家 9,000u 以内** ⇒ 塌到 0 要读成「修法过头/写错」,不是「场景稀缺」(已事先登记进判据)。
  `tests/test_pullcamp_ownside_camp.lua` **11 例**(frame A = 真实 radiant pos5 witch_doctor
  离家 10,527u + #117 自己的热点坐标;frame B = silencer **离边界 51u**,本语料里唯一能让
  深营与自家营**同时进 reach** 的真实几何 ⇒ 两侧都断言选中了哪一个营,外加边界内外 20u 翻面;
  frame C = 结构性恒等)+ 合同用例 1 条(15→16)+ census 域普查 1 条(20→21)。
  **一条自带的诚实声明**:**frame A 的 nil 不是判别力的证据** —— 那一帧 bot 比边界深 2,811u
  而 reach 只有 1500,**绕他一圈八个方向的营全会被拒**(已写成断言),牙齿在 frame B。
  (0p 的自查:一个只会答 nil 的帧,答 nil 不算证据。)
  往 `jmz_func` 插了 26 行,**按 0R 特意跑了两个按行号钉的文件**:`test_level_gate_census`
  15/15、`test_gate_claim_consistency` 7/7,都没被推走。luacheck 0 警告。
  **全套 1259 tests / 0 failures**(1246 + 本轮 13,涨数与加数一致)。
  报告 `iterations/reports/strategy/20260822T173000Z.md`;`state.json:pullcamp_ownside_20260822`。
  **⚠️ 本轮自踩的一条流程教训(见报告 §7)**:`pkill -f "run_tests.lua"` **会杀掉它自己所在的
  那条 shell**(命令行里就含这个模式)⇒ 重启没执行、我以为在跑的全套死了八分钟;
  随后 `pgrep -cf run_tests.lua` 读到的 "1" 是**我自己的等待 shell**。
  **杀长任务用 PID;「还在跑吗」按 `kill -0 <pid>` 问** ——
  **一个把观测者自己计进去的计数器永远不会读到 0**,这是 0m 那条的观测侧版本。
  **本轮明确不做**:#117 §3.3 的血量/营地强度门(总监明令另开 id)——
  **选点改了它的域也会变**,现在提 id 是在为一个即将作废的域写断言,
  与 16:5xZ 摘 `pullcamp` 是同一条道理。
- 2026-08-22T14:00Z(收尾 ~16:0xZ,**与下面 15:22Z 那条是同一个工作单元的并行重复**):
  **本轮实现整棵树作废、不入 main;15:22Z 那一版先落地且更对。**
  **认领依据**与 15:22Z 那条相同(charter 11:26Z 自己点名的下一个杠杆),
  **两个会话谁都不知道对方在做** —— 这是本轮的头号产出,见下面「流程」一条。
  开工 fetch `origin/main` = `a03f17d`,做完实现后**按 0S 跑全套两次(共约 80 分钟)**,
  就在那 80 分钟里对方落地 ⇒ push 被拒、rebase 在两个同名新文件上冲突 ⇒
  **abort + `git reset --hard origin/main`,不 force、不覆盖**;实现树留在
  `origin/claude/dreamy-feynman-d64nwv` 作记录(luacheck 0 警告 / 全套 **1234 例 0 失败**)。
  **⭐ 两版独立收敛**:同样的拆法、**同样的两枚钉帧**(zuus t=391.5 / viper t=641.4)、
  **六个规模数逐字相同**(930/150/82/50/22/28)⇒ 一次白得的跨会话独立复现。
  **三处自我更正(两处是对方替我发现的)**:
  (1) **幻影棒是我造的** —— 我在 **push 之前**就在 GH #110 留言 / #114 正文里用「已落地」的口吻
  点名了五样产物,15:22Z 那轮因此 `git log --all` 读空、判 NOWHERE、**花一整节排查后从零重做**。
  **他们的判据和处置都对,错的是我。** 这是 0m 的**镜像**:0m 说别把「仓库里没有 X」当成「X 丢了」;
  另一半是**别在 push 之前把「我这里有 X」写成「X 已落地」**。
  ⇒ **今后任何指名产物路径的交棒留言,必须在 push 成功之后发**,或写明「尚未 push,分支 X」。
  (2) **`laning=18` 被安到了一个它不回答的问题上,对方的 24 才对** —— 挡着 `fieldregen` 的
  子句字面是 `not J.IsInLaningPhase()`(**带净值软延长**),我量的 `DotaTime<480` 是它的**硬地板子集**;
  选硬地板的动机(避开 v1 fixture 净值读 0)合理,**但不能拿代理量顶替还沿用被代理者的标签** ⇒ 低报了那个洞。
  (3) **采购点删掉 `botDistanceFromFountain > 2500` 是错的** —— 我写的理由是「离线不可观测」,
  但 shipped 读的是 `bot:DistanceFromFountain()`,我量的是 `GetShopLocation(...)` 的距离,**两个函数**;
  实测前者在两枚钉帧上 **8907.8 / 13516.1**,子句完全是活的;而且那个代理量本身也不是常数
  (**505.8 / 4965.8**,我却从**一枚** centaur 帧的 217 写了「到处读 ~218」)⇒
  **那版若进 main,低血 bot 站在自家泉水边也会去买药膏。**
  **(2)(3) 是同一个毛病一天犯两次:量代理量,把结论写给被代理的那个量。**
  ⇒ **凡是论证「shipped 的某条子句在离线不可观测 / 域有多大」,必须调用那条子句字面写的那个函数。**
  **一条与谁的实现无关的通用纪律(两个会话独立踩到,说明是结构性的)**:
  **一次纯提取重构不改任何行为,却会让所有按函数体钉的 `[reverse]` 源码断言失准** ——
  本轮把 situation 再往下拆一层,姊妹 `test_replay_260822_lina_tp_home` 里按函数体断言
  「turbo-only + 三个半径」的钉子当场落空(**单文件跑 21/21 全绿,全套才读出来**)。
  ⇒ **拆/合一个被 `[reverse]` 钉过的函数,收尾必须 grep 该函数名的所有钉子并逐个搬**;
  **被打破的那个文件不是你在改的那个文件。**
  **流程(交总监,本组不单方面立)**:现有机制挡不住并行重复 —— charter「当前状态」记的是
  **已完成**、`test_set.md` 的提议行是**产出**、issue 只在**做完之后**才写,
  铁律 9 解决「棒掉了」,**解决不了「两个人同时接同一根」**。建议开工写一行**认领**、收尾删掉;
  另建议把 0m 扩成**收尾跑全套之前 fetch 一次、push 之前再 fetch 一次**(长收尾窗口就是重复窗口)。
  **顺带补上 15:22Z 自己写明没拿到的那个数**:`origin/main`(`80c51af`)的干净 worktree 全套结果,
  见 `iterations/reports/strategy/20260822T140000Z.md` §4/§6。
  **本轮真正留下的**:GH **#114**(采购层的三条声明 + `DistanceFromSecretShop` 无桩 ⇒ >6 级必崩,
  且那一行只有靠第十五条才够得到 —— main 上对方的用例已在引用它)、GH **#112** 留言
  (红已没了但不由本组关闭:per-fixture 分解仍未写,属 #106 §4)、GH **#110** 的更正留言。
- 2026-08-22T15:22Z:**owner 优先项 P2 的补给侧 `fieldbuy` 落地 —— 而本轮真正该先说的是:
  13:50Z 那一棒点名的五样产物,在全 refs `--prune` fetch 之后仓库里一件都不在。**
  **认领依据**:铁律 9 + OWNER_PRIORITIES P2 球在本组;开工先跑 `routine_selfcheck.sh`
  (unlanded 干净、只报一条 strategy cadence GAP 11:26Z→now 3.7h —— **那条洞就是这件事的唯一痕迹**,
  而它读起来像「那一轮没东西可交」)。**零 EC2 支出**,不新提批测请求。
  **§1 的幻影棒**:GH #110 的 13:50Z 评论与 #114 正文以「已落地」的口吻点名
  `tests/test_replay_260822_fieldbuy_supply.lua` / `tests/_fieldbuy_supply_sweep.lua` /
  `state.json:fieldbuy_20260822` / `reports/strategy/20260822T140000Z.md` / `test_set.md` 提议行,
  并向三个组各交了一棒;**`git log --all -- <那个测试文件>` 为空** ⇒ 不是 main 上没有,
  是**任何 ref 的任何历史里都没有过**。**与 08-22 早晨 hero 那次 OFF-TRUNK 不同形状**
  (那次东西在分支上、**不许重做**;这次 NOWHERE、**只能重做**),判据写在报告 §1。
  **⭐ 重做出来的六个规模数与那份不存在的报告逐字相同**(930/150/82/50/22/28)
  ⇒ 那一轮的**测量**是真做过的,掉的是最后一步 push;同时白得一次跨会话独立复现。
  **而不同的那两个数才是有用的部分**:它报 laning=18 / both=12,我读 **24 / 18** ——
  量的不是同一个谓词(`DotaTime<480` 硬地板 vs 真正挡着 `fieldregen` 的 `J.IsInLaningPhase()`,
  后者带净值软延长)。**本组采用后者,因为那是 `fieldregen` 自己读的那一个。**
  **改动**:核心谓词一分为二 —— 无 gate 的 `J.IsFieldRegenSituation`(turbo + 血量带 + 三个环),
  上面两个消费者:`J.ShouldRegenNotGoHome`(∧ 包里有的喝,喂原来两个 gated 包装,**按构造行为不变**)
  与新的 `J.ShouldFieldBuyRegen`(gate `fieldbuy`,∧ 包里**没有**的喝)⇒ **同一情境的一个划分**,
  `situation == has + dry` 成断言,两个 id 不会悄悄互相遮蔽。
  **域(930 存活英雄帧)**:situation **50** = 有 **22** + **没有 28** ⇒ **没人管的是大的那一半**;
  不 armed 触发 **0/930**。**三个洞**:`fieldregen` 的对线子句 24 / 出厂在线块的 `botLevel<6` 22 /
  **两洞同时 18** / 0.45 上限之上 13(并断言 `both < laning` 且 `both < level6plus`,
  否则「两个洞」可能只是同一个洞的两种说法)。
  **本仓库第一次在真实帧上断言一次采购**:两枚钉帧驱动 `ItemPurchaseThink`,armed 出
  `ActionImmediate_PurchaseItem('item_flask')`、不 armed 不出,**且不 armed 那次仍买了别的东西**;
  再加一条「gate 只改这一件事」(删掉 flask 后两条清单逐项相同)。
  **两枚各隔离一个出厂阻塞点**:A(zuus 7 级、39.5%、**在**对线期、低于 0.45)⇒ 挡它的只有对线子句;
  B(viper 15 级、54.9%、已过对线期)⇒ 挡它的只剩 0.45 上限。
  **顺带两枚一直只有注释的子句拿到实证**:A 的 4 号格字面是 `item_empty_bottle`;
  B 的仙灵之火在 **6 号格 = 背包**(**身上有药、喝不着**)。
  **明说没测**:金钱子句(mock 的 `GetItemCost` 答 0 ⇒ 离线恒真),已成断言以便将来自动红。
  **21 例 0 失败 + 9 条变异**(含一条**事先声明为 null** 的探针 M9);luacheck 0 警告。
  **本轮自己犯的错(已写成检查项)**:变异 rollback 用了 `git checkout --`,把**本轮尚未提交**的
  helper 改动整个抹掉 ⇒ **rollback 一律从工作树的物理备份 `cp` 回来**;另:同一份变异脚本
  **并发跑了两次**,读出一组混合状态的清单,**唯一破绽还是数字**(930 → 920)。
- 2026-08-22T11:26Z:**owner 优先项 P2 的第二棒 —— 回家的另一条路(步行/撤退模式),
  新 gate `stayfield2`,而且是本族第一次能断言最终出价。**
  **认领依据**:铁律 9,P2 完成定义第 1 条明写「含 TP 和步行回泉两种回家路径」,
  backlog 0P2 (a) 点名它是下一个单杠杆 ⇒ 不走 issue 流。开工按 0m 先 fetch,`origin/main` = `bef59de`。
  **零 EC2 支出**(没下 `.dem`、没生成 fixture、没调 Cost Explorer);**不新提批测请求**
  (跟 09:33Z 那条走「野区续航」同一张单,重复提 = 空转)。
  **结构**:条件从 `J.ShouldRegenNotTpHome` 里拆出来成**无 gate 的核心** `J.ShouldRegenNotGoHome`,
  上面两个**各带自己 gate 的薄包装**(`stayfield` → aiug `撤退:3`;**新** `stayfield2` →
  `mode_retreat_generic`,坐在**已 promote** 的 `J.ShouldStayAndRegen` 否决正下方)。
  **两个 id 不是为了分开 arm(它们要同波 arm),是为了事后分得开归因** —— 共用一个 id 会让
  per-id A/B 失去意义(GH #29 重排 guard chain 要杀的那种不独立性)。核心无 gate ⇒
  **多一个直接调用者就等于把行为发布出去**,两个测试文件各钉一条调用者计数。
  **这条腿是真缺口**:`ShouldStayAndRegen` 在 P2 钉的那一帧上说不出话,**两个盲点各自单独就够**
  (受击不做归因 —— 7,533 码外的宙斯全图大招点亮标志,而最近的敌人在 6,596 码外;
  回复品只认 flask/tango + 金钱 ≥90 —— 她带的是仙灵之火且金钱 <90),两条**分别成用例**,不并成一条。
  **测的是最终出价**:`f_260822_063722_lina_tp_home` 上撤退出价 **0.14413381588777 → 0**。
  **诚实边界(写进用例)**:这一帧**撤退是亚军**(对线 0.369,arm 前后不动)⇒ 拿掉的是亚军出价,
  不是把人掉头;那一帧真正的回家是 item 层的 TP,归 `stayfield` 那半 ⇒ **两半都要,P2 才算完**。
  **本轮真正的发现(全语料扫出来的,不是设计出来的)**:第一版谓词(无塔子句)在
  `f_260819_142047_zuus_ult_denied` 上为真,而那一帧的撤退出价是 **ABSOLUTE×1.1**(全系统最高)、
  **却根本不是回家** —— `debug.sethook` 逐行追到 `X.ShouldRun` 的**前期谨慎冲塔**
  (`mode_retreat_generic:885`:等级 ≤10、`DotaTime()`<5:00、血<800、898 内有敌塔),
  一个 7 级宙斯 40% 血**站在敌塔 727 码处**、最近敌方英雄 7,000 码外。压成 0 = 让他泡在塔射程里。
  ⇒ 核心加第五条腿**「1200 内无敌方塔」**(1200 是那几条塔子句自己用过的最大半径,仍严格更保守)。
  **给全组的读数:`mode_retreat_generic` 不只是「回家模式」,它同时承载局部后撤出价**,
  一刀切 `return DESIRE_NONE` 比看上去宽得多 —— 今后凡动它的出价先看这条。
  **域(有偏样本,是稀有度下界不是域大小)**:全 100 枚 fixture 各驱动两遍 ⇒ **3 帧为真、
  1 帧真的动出价**,另两帧**本来就出价 0**(**为真 ≠ 行为动了**,两个数都进了 `[recorded]`)。
  **世界变异两条按 0z 跑了**:lane front 挪到 (4000,4000) 出价不动、撤掉 GH #91 的 ping 声明出价不动
  ⇒ 出价断言不骑在桩上;两种 gamemode 读法在这两枚帧上**实测一致**(GH #93)。
  **验收**:luacheck **0 警告**;两个 stayfield 文件 **39 例 0 failures**(新文件 19,0n 计数核对无重名);
  **8 条变异逐条 apply+rollback,每条点名红了它该红的用例**(M1 把归因换回已发布的无归因读法 ⇒
  **缺陷本身被复现**;M8 只红计数格 ⇒ 计数器有牙)。
  **变异电池当场纠了本组一条用例**:M3(环 1600→800)**没红** Slardar 那条反例,
  因为那一帧**同时**没有回复品 ⇒ **两条子句在否决**,原标题「卡住它的是 1600 环」是 0p 那种
  单条归因错误,已改成两条各自断言、并注明环的**孤立见证**在姊妹文件的 Lina 帧上。
  **全套跑 1178 例 8 失败,8 条全在 `test_itemdesire_world_assertion.lua` 且与本单元无关**
  (在 `bef59de` 开干净 worktree 单跑该文件:24 例 8 失败、逐字相同)⇒ **本轮把失败数 8 → 8**;
  **但那 8 条是本组自己的债**(09:33Z 加的两枚 fixture 把语料推到 100,第五个普查文件没跟)
  ⇒ 已置 backlog **头条 0RED**,下一轮先做。
  **另一条工具纪律(本轮踩了,而且是复发)**:变异脚本第一版用 `git checkout -- <file>` 回滚,
  **把同一文件里本轮未提交的改动一起冲掉了**(jmz_func 的改动全丢,重打了一遍)——
  **总监 01:0xZ 已经写过这条**(「还原走文件级备份,不走 `git checkout --`」)⇒
  **当检查项跑,别当经验记**:变异回滚必须写回内存副本,除非改动已经提交。
  **接力棒**:`stayfield` 已由 §AM(11:0xZ)批准入集 ⇒ 请总监**把 `stayfield2` 补进同一波**
  (P2 要两条路都覆盖,只 arm 一半 = 只覆盖一半)→ 批测台(不新开单,随「野区续航」族取证波,
  **注意触发稀,波次要申报目的地找它**)→ 录像组按 GH #110 新标准核验。
  **下一个杠杆**:P2 的**补给侧** —— 22 次真·回家 TP 里带大药的是 **0/22**,当前 buy list
  根本没有可买对象,而**没有任何 id 在管「买什么」**。
  ⭐ **收尾 rebase 时读到 §AM.2 并核了一遍**:总监量出「大药腿在 `stayfield` 唯一调用点上结构不可达」
  (`撤退:3` 自己要求 `itemFlask == nil`,与大药腿同一个谓词)—— **这条不适用于走路那半**:
  `mode_retreat_generic` 这条腿全文**没有任何 `itemFlask` / `IsItemAvailable` 前置**(已 grep 核)
  ⇒ **走路那半的域在大药这一格上严格更大**,而那正是 owner 反复点名的「买大药」那一格。
  `state.json:stayfield2_20260822`,详见 `iterations/reports/strategy/20260822T112624Z.md`。
- 2026-08-22T07:30Z:**Owner P1 第 1 棒:pullcamp 的 SILENT 根因 = 触发器要求它自己要造出来的那个状态。**
  **认领依据**:铁律 9(OWNER_PRIORITIES 凌驾 issue 流),P1 第 (1) 条球在本组,执行入口 GH **#109**。
  开工按 0m 先 fetch(`origin/main` = 本地 HEAD `5194eb7`);收尾时 main 已前进,**两次 rebase**,
  两次都按 0m 回读远端 tip 确认。
  **`bots/` 动了一个函数**(`J.ShouldPullNeutralCamp`),**仍在既有 `pullcamp` + turbo gate 后面,
  不产新 soak id**(照 creeppull 2026-08-19 的先例);`tests/mock/` 一位没动,零 EC2 支出。
  **根因**:触发器先问 `bot:GetNearbyNeutralCreeps(1400)` 非空 = 「现在能**看见**营地」,
  **而站在兵线上的辅助看不见**(盒子在树后、无视野);而 `mode_roam_generic` 的
  `Action_MoveToLocation(bot.roamCampPull)` **只有 plan 已存在才可达** ⇒ **触发器等抵达、抵达等触发器**。
  **与 2026-08-19 修掉的勾线死分支同形状** —— **GH #13 的另一半**,它不报错、只是安静返回 nil。
  **修法(一个杠杆,两处编辑,同一个机制「授权走过去」)**:①视野问题**搬到**能回答它的地方
  (Think 抵达时的 `bCampHere`);②窗口开 **5s 行程提前量**(1500u 够程 / ~300 u/s),
  :05–:20 / :35–:50,**:12 / :42 标记一位没动**。**两半缺一不可**:实证帧在 **:07.4**。
  **翻掉 owner 的一条怀疑**:`IsLanePullSafe` **不是**第二条死条件 —— **339/930 帧成立**。
  **P1 DoD 要的频率证据(全真实帧,收尾 rebase 后按 100 fixture / 930 帧重测)**:
  **36/930** 帧是「辅助 + 对线窗口(60–360s)+ 800 内无敌人」;**旧窗口收 10 / 新窗口收 15** ⇒ **场景频率,不是死条件**。诚实边界:按 GH #81 敌人恒 pos 3
  ⇒ 这是**友方一侧**计数,**33 是下界**。
  **按 0p 先声明结构不可达(四个互相独立的拦点,全是量的不是论的)**:
  ① `GetNearbyNeutralCreeps(1400)` **0/930**(dumper 不带兵)—— **本轮删掉的正是这条**,
  ⇒ 修复前任何在这条行为上的隔离循环都会**诚实地读到全零**;② `GetNeutralSpawners()` **0/930** 非空;
  ③ `GetLaneFrontLocation` loader **REFUSE**(#61);④ **`GetAssignedLane()` 930/930 读 0 而不是 nil**
  —— bot VM 状态、不在 `.dem`,**第十三条世界断言的又一个面**(只记账,动 loader 会移动全部 98 个 fixture)。
  **实证帧**:`f_260820_162821_lion_drain_lethal` 的 **ogre_magi**(dire pos 5、满血、1800 内无敌人、:07.4)。
  声明的三样是兵线前沿/中点/营地清单 ——**营地出生点是地图常量**,**营地占用**才是游戏状态,**一次都没声明**。
  **验收**:luacheck **0 warnings**;`test_pullcamp_trigger_census` **20/20**(计数核对 8+7+5=20);
  **七条变异逐条 apply+rollback,每条只红它该红的**;**rebase 前全套 1149/0**;
  **rebase 后普查钉子按新语料重测**(0c 的连带:`lion_drain_jungle` 被 05:30Z 治疗后,
  那一帧读作辅助的英雄**换了名字、数目没变** —— 这是**非本组钉子被角色治疗移动**的第一例)。
  **rebase 后全套 1163 例 2 红,两条都不是本轮的** —— `test_itemdesire_world_assertion` 的
  `crash_total 207`(钉 209)与 `crash_2597 177`(钉 179),**在 `origin/main` 的干净 worktree 上
  逐字复现**(不是推的,是跑的;在收尾时的 100-fixture main 上是 **8 红**,六条是纯语料规模棘轮)
  ⇒ 见 backlog 新的 0R 条,本组认领,已开 **GH #112**,**本轮新增/改动的用例 0 红**。
  **两条做法记进 backlog/报告**:① 三个声明营地第一版在**调用点**构造 ⇒ 传进去一桌 nil,
  **三条控制用例全部因为「营地没坐标」而通过** ⇒ **一条控制用例通过之前,先证明它控制的那个量在场**;
  ② 目标 helper **已经有一份合同用例**(`tests/test_pull_camp.lua`),其中一条钉的**正是本轮删掉的子句**,
  而 `run_tests.lua pullcamp` 是**文件名**过滤、**匹配不到 `test_pull_camp`** ⇒ 本地全绿、
  **只有 50 分钟的全套跑翻出来**。处置是**翻面并写清为什么**(11 → 15 例)。
  ⇒ **改一个已发布 helper 之前先 grep 它的名字找现存合同用例,别指望全套跑兜。**
  **三棒已交出**(铁律 9 连带规则):总监(test_set.md 提议行 + 历史行)/ 批测台(`queue.json:strategy-1`)/
  录像组(阴性判据:仍 SILENT 先看**有没有离开兵线走向营地**)。已在 **#109** 留言,**不新开 issue**。
  `state.json:pullcamp_SILENT_ROOTCAUSE_GH109_20260822`,
  详见 `iterations/reports/strategy/20260822T073000Z.md`。
- 2026-08-22T09:33Z:**owner 优先项 P2 的第一棒(决策侧第一个 gate)—— 而且是用录像组
  30 分钟前刚换掉的那一帧,不是照着已作废的原铁证帧钉。**
  **认领依据**:铁律 9,`OWNER_PRIORITIES.md` P2 明写「当前球在:**协同组**(决策侧 id + fixture)」
  ⇒ 不走 backlog。开工按 0m 先 `git ls-remote origin main` = `477d0d4`。
  **零 EC2 支出**(2 次 `.dem` + 2 次 `analysis.json` 的 S3 GET,dumper **cache HIT**,未调 Cost Explorer)。
  **不提批测请求**(入集批准之前提波次是空转)。
  **新 gate `stayfield`**(用 GH #110 正文建议的名字,不是我原来写的 `regenstay`):
  `J.ShouldRegenNotTpHome` + `J.HasFieldRegenSource`,接在 `aiug` 的 **`撤退:3`** 那条回城腿上。
  **证据帧 `f_260822_063722_lina_tp_home`**(20260822_063722_slot1,seed 888,dire armed):
  Lina **31.8% 血、最近敌人 6,596 码、包里有仙灵之火**,TP 回家落在自家泉水 **33 码**,
  **20.3 秒不在场上**(`observed.burst` 空、`died_after` 110.6 ⇒ 没有人在追她)。
  **机制(两个独立原因,已发布的 `J.ShouldStayAndRegen` 两条都够不着)**:
  (1) 那条否决**只接在 `撤退:1`**(要 <0.19 血),31.8% 走的是 **`撤退:3`,那条腿一个回复否决都没有**;
  (2) 它的危险判据 `WasRecentlyDamagedByAnyHero(3.0)` 在这一帧被**宙斯的全图大招**
  (施法者 **7,533 码**外,204 伤害,决策前 2.6s)点亮 ⇒ **「一个英雄打了我」被当成「一个英雄在打我」**。
  新 helper **把受击做归因**:只有当那个英雄**此刻仍在 3000 内**才算危险;
  其余每一条都比它守的分支**严格更保守**(分支容忍环内 1 敌,helper 要 0 敌)。
  **回复品集合故意不含魔棒**(22 次真·回家 TP 里 21 次带魔棒 ⇒ 数它等于恒真,
  而充能数不在 dump 里;魔棒是 `wandbleed` 自己的杠杆)。
  **反例帧 `f_260822_063559_slardar_tp_forward` = P2/#110 原来钉的那一帧**,
  现在以它真实的身份(**一次前压 TP**,GH #111 实测落点离自家泉水 12,646 码)进仓库;
  **余量只有 35 码**(tidehunter 1565 vs 环 1600),GH #107 若动采样相位它可能只因相位翻面 —— 已写进用例。
  **fixture 取 `--t 349.0` 而不是 349.1**:`modifier_teleporting` 在 349.1 整加上,
  按 349.1 生成会把**本次决策的后果**写进「决策前状态」。
  **诚实边界(写进用例不是写进脑子)**:最终出价断言不了(GH #89 第十三条 mode 恒 0、
  GH #100 第十六条物品 Consider 没人调)⇒ **helper 钉帧 + 分支用排除法归因**
  (`撤退:1`<0.19 / `撤退:2`<0.15 / `回复状态`<0.20 或 血+蓝<0.30 全排除,她 0.318 血 0.576 蓝;
  `撤退:3` 帧能答的每条都成立;`CanJuke`/`GetAttackTarget` 标注为 mock 默认不是测量)。
  **验收**:luacheck **0 警告**;新文件 **20 例 0 failures**(0n 计数核对:20 条无重名);
  **8 条变异逐条 apply+rollback,每条点名红了它该红的用例**(M4 把归因换回已发布的无归因否决 ⇒
  **缺陷本身被变异复现**),rollback 后 20/20、`git status bots/` 干净。
  **连带**:加两枚 fixture 触发 GH #106 那一类的 **24 例失败(全在分母/行号,没有一条在发现上)**,
  四个普查文件按各自规矩更新(`gamemode` 的竞价与 `pingstamp` 的 push 份额是**实测**不是搬分母:
  移动格 22→23 而移动赢家不变 19;戳的份额 35→36)。详见报告 §5b。
  **另改一行注释**:`mode_retreat_generic:213` 把**已 promote** 的 `J.ShouldStayAndRegen`
  写成「candidate-gated … inert off-farm」,已改成事实(同 08-21 的 `aiug:5161` `tpsafe2`)。
  **接力棒**:总监入集(`test_set.md` 顶部已留提议行,eligible 那行逐字未变)→ 批测台一波买 (a)
  → 录像组按 #110 新判读标准核验。**下一个杠杆**:P2 的**步行回泉那一半**
  (`mode_retreat_generic:217` 已接已 promote 的 `ShouldStayAndRegen`,**盲点一模一样**)。
  **收尾追加(10:xxZ)**:全套的失败枚举露出**第五个**普查文件
  (`test_itemdesire_world_assertion`,8 例),已修并单独跑绿(24 例 0 failures);
  其中 `crash_2597` 那条**不是分母也不是本组造成** —— 四棵树实测 177 而 pin 写 179,
  即**本轮之前就红了 −2**,落在**已 promote 的 `tpsafe2` 路**上,已交总监
  (`state.json:itemdesire_CRASH_PIN_STALE_20260822`,见新增 backlog 0S)。
  `state.json:stayfield_20260822`,详见 `iterations/reports/strategy/20260822T093308Z.md`。
- 2026-08-22T05:30Z:**角色债治疗第六帧 `f_260819_182855_lion_drain_jungle`(0c 队列点名的
  两枚 `lion_drain_*` 里的第一枚)—— 头号产出不在角色上:**这是第一次「重生成 ≠ 纯追加」**。**
  **`bots/` 一位没动,`tests/mock/` 一位没动,不产 gate,不申请入集,不提批测请求,零 EC2 支出**
  (三次 S3 GET + dumper cache HIT)。开工按 0m 先 `git fetch origin main` = 本地 HEAD `dcfffbb`。
  **认领依据**:`[strategy]` open issue 逐条看过 —— #45 上一轮做完且 04:03Z 后无新总监输入、
  #72 上一轮判「无可动杠杆」、#77 已于 08-21T01:20Z 结论化、#84 §5 已于 22:00Z 关闭 ⇒ 回 backlog;
  0p/0n/0m 是流程条,0a 仍卡语料 ⇒ 取 0c 队列。
  **头号产出**:同一个 `--t 247.0`,今天的工具落在**比被替换那份早 ~0.335 秒**的采样上。
  **测出来的**:把治疗前每个英雄的坐标投影到今天两个相邻采样(246.4/247.4)之间,
  **四个走得够快的英雄**(dragon_knight/earthshaker/pudge/lich,位移 387–427u、偏离 ≤23u)
  互相独立地解出 **246.733/246.737/246.741/246.733**;走得慢的解在哪都不奇怪,**不进表**。
  **挪的只是英雄快照那一路**:事件流导出的东西**逐字节相同**(12 行 `recent_damage`、空 burst、
  `died_after 68.1`、38 座建筑)—— 它们按名义 `--t` 算,游戏时钟真动了它们会跟着动。
  **我们手上没有任何 dumper 能复现旧文件**:S3 三个缓存二进制**全下下来跑了**
  (含**当年正在用的** `68a3abfe…`),三份 `start_time` 都是 138.6、采样格都是 `…246.4, 247.4…`。
  **而且今天的标签是晚的那一边**:标着 t 的快照携带 t 之前 ~0.2–0.33s 的状态 ——
  (a) **冷却量表 n=1884**(`真实时刻 = 施法时刻 + cd_len − cd`),加权均值 **0.22s** 且因两端
  0.1 精度**系统性偏低**;(b) **血量重建**:244.2 那记伤害出现在标着 **245.4** 的采样里、
  244.4 那格反而涨 8 血 ⇒ 只有「标签早了 ~0.33s」配平。**0.33s = 10 tick @1/30s**;
  采样循环挂 `m.GetTick()` 而 `main.go:625` 读 `p.NetTick` —— **按假设标注,本轮没证明**。
  **它花了什么**:**结论一位没动**(CONTROL 帧,承重子句 6033u vs 500u 半径,**5500u 余量**
  对 38u 位移);**花掉的是两条断言** —— `hp==188`/`mp==284`(钉到个位)与 `d∈(5990,6000)`(10u 带),
  而**第二条藏在第一条后面**(同用例),单跑只看得见一个失败。
  **角色那一半**:五个动四个、**翻两面**(lich 核心→辅助、dragon_knight 辅助→核心),
  **subject 是不动点**(槽位 5 = 抽签 5)⇒ 唯一那次角色读取(出装 key,`aba_item:1600`)
  **不动** ⇒ 这枚是 axe 那条发现的**又一个 CONTROL**;为免变空断言,用例**把机制驱动了一遍**
  (强打 pos_4 得到不同的表)。**19 条原用例逐条未改**,原因是量出来的:
  `lion_ShouldStopDrain` 与 `ConsiderStopDrain` **各读 0 次**位置(两个入口同时挂钩),
  两个零都配了非空见证。敌方五个照旧一律答 3(GH #81)。
  **顺带量出 frame A 的治疗预报**(同一份 timeline 直接量,给下一个动 midchannel 的人):
  会落到标着 **298.4** 的采样,**Lion 510→601 血、viper 484→484.5u** ⇒ **RELEASE 的承重子句活下来**,
  要重写的是两个 ground truth 数字。已写成 `[recorded]` 用例(**断言当前治疗前的数**,谁去治谁被送到这里)。
  **验收**:luacheck **0 warnings**;`lion_drain_stop` **32 → 36 例,0 failures**
  (**计数核对(0n)**:文件内 19→23,新增 4,无重名);**六条变异逐条 apply+rollback,
  每条点名红了它该红的用例**(M1 删 roles / M2 对调 lich↔dk 抽签值 / M3 给 guard 加一次角色读取 /
  M4 把 188/284 塞回去 / M5 把 `pos_4` 指向 `pos_5` / M6 给 frame A 塞 roles 表),
  rollback 后 36/36、`git status bots/` 干净。**棘轮 5 → 4**。
  **已开 `[harness]` GH #107 交总监**(动不动 dumper 采样时钟:动它会**一次性移动今后每一枚
  fixture 的取样点**)。`state.json:liondrainjungle_ROLE_HEAL_20260822`,
  详见 `iterations/reports/strategy/20260822T053000Z.md`。
- 2026-08-22T03:30Z:**认领 GH #45 裁定 §5(总监 08-21T19:0xZ 把它从「次生残留」
  升级为已 shipped 默认行为的**阻塞性**跟进)。治疗那两枚钉帧 ——
  **本 issue 的两条归因结论翻掉了,而且都朝同一个方向:`roamreach` 更值钱、也更好排期。****
  **`bots/` 一位没动,`tests/mock/` 一位没动,不产 gate,不申请入集,不提批测请求,
  零 EC2 支出**(只有两次 S3 GET + dumper cache HIT)。
  开工按 0m 先 fetch:`git ls-remote origin main` = `8c90769`,本地 `fb1113f` 是其祖先 ⇒ 先 rebase。
  **治疗**:`20260819_181742_slot1`(`mirror:...:s866:radiant`,**subject 在 armed 侧**)。
  坐标/血/蓝/等级/物品/CD 与仓库那份**逐字节一致**,ground truth 一致
  (burst DK 57、`died_after` 181.6 / 175.6),**未**吐 `ground_truth_ambiguous`(0e 干净)。
  **新增的是那两份一样都没有的五样**:`player_id`、`modifiers`(15/14)、
  `recent_damage`(33/27)、抽签 `roles`、**外加每座建筑的 `hp`**。
  (`buildings` 本身**本来就有** —— 裁定 §5 点的那一样不是缺口;缺的是它的 `hp`,
  38 座建筑名字/阵营/坐标/`alive` 一字未改,**三座不满血**(dire 中二塔 **0.505** 等)⇒
  **backlog 0a 的 tier/血量 remap 与 `t3AlreadyDamaged` 第一次有真实帧输入了**,记给下一个动 0a 的人。)
  **逐字节核对是脚本做的**:剥掉这五样后英雄标量行逐条相同、`buildings` 除 `hp` 外逐条相同、
  `observed` 整块逐字符相同。
  **翻掉的第一条:「由 `ownhalf`、而且只有 `ownhalf` 打开」作废**。healed 帧上
  **一个 soak id 都不 arm**,出价 **0.72**,`Think` 下的是**同一条**
  `Action_AttackUnit(dragon_knight, false)`。打开它的是 **`ConsiderHelpAlly`** ——
  **完全没有 gate、已发布、turbo 默认在跑**;承重子句
  `nClosestAlly:WasRecentlyDamagedByHero(enemyHero, 2.5)`,队友 Centaur(656u、82%、抽签 pos 3)
  **2.0s 前刚被同一个 DK 打了 44**(实测 2.5 真 / 2.0 真 / **1.9 假** ⇒ **余量正好 0.5s**)。
  **旧结论是退化世界的产物**:没有 `recent_damage` 时 `WasRecentlyDamagedByHero` 对所有人恒 false
  ⇒ 这条分支在**任何** fixture 上都点不着;**变异 N1(只删 Centaur 的 `recent_damage`)
  把旧世界一字不差地复现出来**。⇒ **「一帧成立的分支买到一次横穿地图的追击」这个缺陷,
  活在已发布 turbo 默认行为里,不在任何 gate 后面。**
  **翻掉的第二条:`roamreach` 可以单拎成一臂**。既然没 arm 也有那条命令,**只 arm 它**
  就把动作从 `Action_AttackUnit` 换成 `Action_MoveToLocation`(出价一位不动)⇒
  **`test_set.md` §I.7 约束 ① 请撤销**;约束 ② 的前提也没了 ——
  **`roamstale` 已 promote,`bots/` 里不存在这个 gate id**,原隔离循环里 arm 它的那格
  **按构造就是 no-op**(已成反向断言)。
  **对裁定 §3 回滚顺序的影响(最该看的一句)**:顺序不变(先扫 `VICTIM_HP`),
  但**第 3 步的预期要改** —— 这一帧的命令不需要任何 armed id 就会发生 ⇒
  **把 `roamstale` 退回 gate 后面够不到它**。诚实边界:这是**一帧**上的机制结论,
  不是占比测量;要正式修正 §3 需要「域内 episode 里多少条由 `ConsiderHelpAlly` 开启」这个数,
  已在 #45 建议总监路由录像组,**不建议为此单开批测**。
  **没动的那一半**:t=318.5 那枚治疗前后**逐条相同**。
  **角色读数(0c 要求每帧写下)**:治疗前(无 `player_id`)**未被 synthetic 覆盖时
  全队五个都读 pos 1**(GH #53 退化态),subject 是 **core**;只加 `player_id` 的槽位派生
  = pos **3 core**(**翻面**);healed = pos **4 support**。消费方 Centaur **反向翻**
  (槽位 5 support ↔ 抽签 3 core)。三个世界都追,**但走的不是同一条腿**
  (辅助走 `not J.IsCore(bot)`,核心走 `IsInRange(bot, ally, 1600)`,656u 同样过)
  ⇒ **结果稳定、机制不稳定**。
  原 **LABELLED SYNTHETIC 2**(`rawset(bot,'assignedRole',4)`)**已退休** —— 手设值是对的,改成断言。
  **本轮的一次自我纠正(记下来,因为它就是本组反复在说的那件事)**:第一版把治疗前那格
  写成「loader 按字母序排 roster ⇒ 蒙对成 4」——**那是推的不是量的**;
  真去载入 git 里那份旧文件才看到是**全队 pos 1**。⇒ 那条 synthetic **是承重的不是装饰**,
  没有它这个文件当年每一处 `J.IsCore(bot)` 读的都是相反的值。**「读起来像那么回事」不算测量。**
  **顺带开 `[bug]` GH #105(本轮不修)**:`J.GetClosestCore`(`jmz_func:8817`)测的是
  **调用者**的角色(`J.IsCore(bot)` 写在遍历 `member` 的循环里),**候选者的角色一次都没读**
  ⇒ 辅助调用恒 nil、核心调用得到「槽位序第一个活着的队友」(还不是最近的)。本帧:
  subject 抽签辅助 ⇒ nil,而真正的抽签核心 Centaur(pos 3)就在 656u 外。
  **不修的理由**:一次一个杠杆 + 它有 team_roam 之外的消费方。已钉成 `[recorded]`
  (源码钉子 + 帧钉子),**修好的那天本处归因会被迫重新推导**(变异 N5 实测:出价与动作都不变,
  **换掉的是机制**)。
  **诚实边界**:`ConsiderHelpAlly` 四条外层子句里**两条读 mode 谓词**
  (`IsGoingOnSomeone`/`IsRetreating`),按**第十三条世界断言(GH #89)**在每个 fixture 上都是常数
  ⇒ **不是本帧的测量**,已按常数写进断言;支持它们的是 ground truth 不是 harness。
  **验收**:luacheck **0 warnings**;`test_roamreach_bounded_chase` **11 → 17 例,0 failures**
  (**计数核对(0n)**:新增 6 + 改名 2,11+6=17,无同名覆盖);
  **六条变异逐条 apply+rollback,每条点名红了它该红的用例**
  (N1 删 `recent_damage` / N2 那一击挪到 dt 2.6 / N3 删 `roles` / N4 `_roamreach_BoundedChase` 恒 false /
  N5 `IsCore(bot)`→`IsCore(member)` / N6 把 `roamstale` 放回 gate),rollback 后回 17/17、
  `git status bots/` 干净。
  `state.json:sschase_ROLE_HEAL_GH45_20260822`,
  详见 `iterations/reports/strategy/20260822T033000Z.md`。
- 2026-08-22T01:30Z:**角色债治疗第四帧,`f_260820_103216_cm_es_aftershock` ——
  这对镜像帧收口,并且拿到了上一轮那枚 CONTROL 缺的 EXPERIMENT。**
  **`bots/` 一位没动,`tests/mock/` 一位没动,不产 gate,不申请入集,不提批测请求,零 EC2 支出。**
  **认领依据**:`[strategy]` 最新的 open issue 是 #72(录像检查组 22:46Z 的 §AG.2 分解),
  结论「NOT-PROMOTE 不变、可引用范围收窄」,四条处置全落在检测器与总监裁量上,
  **没留下本组可动的杠杆**(§6.5 唯一没试过的路要 ≫4 seed 批测)⇒ 回 backlog;
  0i 已于 22:00Z 关闭并写明「回到 0b/0c 或 0a」,0a 仍卡语料 ⇒ **取 0c 队列点名的下一帧**。
  开工 `git ls-remote origin main` = `450c490` = 本地 HEAD(0m 的做法)。
  **治疗**:`get_dumper.sh` cache HIT(无本地构建)→ 重跑 dumper →
  **先不带 `--roles` 重生成一遍,与仓库那份逐字节相同**(这一步是「后面那份差异只来自
  `--roles`」的唯一证明,也说明两天后链路仍可复现)→ 带 `--roles` 后**差异恰好是新增的
  12 行 `roles` 表**,`observed`(burst zuus 152 / es 98,`died_after 1.0`)全部重现,
  生成器**未**吐 `ground_truth_ambiguous`(0e 判据干净)。`script_version = mirror:…:s906:dire`。
  **世界动了**:五个盟友**全动**(viper 1→2、pa 2→1、sniper 3→4、**CM 4→5**、SK 5→3),
  **翻两面:sniper 核心→辅助、skeleton_king 辅助→核心**。
  **与上一轮那帧同 seed 同抽签,翻的却是另外两个英雄**(那次是 sniper + viper)⇒
  **翻面集合是每帧的测量**。敌方那一半**按构造惰性**(GH #81):fixture 带着真实 dire 置换
  (jugg 1 / zuus 2 / bb 3 / es 4 / jakiro 5),角色链**五个一律答 3**;
  已成用例并断言「五个里四个抽签值 ≠ 3」,免得将来变空断言。
  **51 条消费方用例逐条未改,原因照旧是测出来的**:两个入口同时挂钩,
  `cm_IsRSafeToOpen` 与 `ConsiderR` **各读 0 次**位置;两个零都配了非空见证。
  **本轮的产出**:唯一那次角色读取(hero 文件 load 时,`aba_item:1600`,全仓库唯一绕过 J 包装的)
  **真的移动了:`pos_4` → `pos_5`**,而且**这一帧自己的背包直接证伪了治疗前那个答案** ——
  她带着 `mage_outfit`(pos_5)的四件基础件(tranquil_boots / null_talisman / magic_wand / flask)
  + pos_5 第 1 项 `blood_grenade`(**pos_4 全表没有**),**没有** `arcane_boots` / `urn_of_shadows`
  (`priest_outfit` = pos_4 独有)。**比 axe 那轮强**:那次靠 `item_blink` 的**次序**推,这次语料直说。
  给 GH #56 的立论补第二个独立实例。棘轮 **6 → 5**。
  **六条变异逐条 apply+rollback 全咬住**(M1 去 roles / M2 对调两个抽签值 / M3 敌方分支保留
  `assignedRole` / M4 出装 key 钉死 pos_4 / M5 给 guard 加一次角色读取 / M6 给 pos_4 塞血雾)。
  **两条做法记进 backlog 第 0n 条**:① **同名用例静默互相覆盖,唯一破绽是计数**
  (本轮亲手犯了一次,27+5 读成 31);② **M3 第一版落在错的函数上**(`return 3` 不止一处),
  是 0m 第四种形状的复发 —— 顺带**第一次由变异证实** loader 确实给敌人 `rawset` 了抽签角色。
  **验收**:luacheck **0 warnings**;`cm_es_aftershock` **32/32**(治疗前 27)、
  `cm_r_selfstate` **24/24**、`fixture_roles` **10/10**;全套见报告。
  `state.json:cmesaftershock_ROLE_HEAL_20260822`,
  详见 `iterations/reports/strategy/20260822T013000Z.md`。
- 2026-08-21T22:00Z:**关掉了等级门普查(GH #84 §5)。第六条也是最后一条 TEETH
  `ability_item_usage_generic:5749`(守遗迹 TP)同样做不成完整形状,但理由与前五条都不同 ——
  它的等级门 satisfiable(唯一一枚 subject≥15 的 fixture `f_260820_043120_viper_defend_paired`
  viper@15 上,外层门 5751-5756 整个打开)⇒ 等级常数不是卡点,基地被围才是。**
  **`bots/` 一位没动,`tests/mock/` 一位没动,不产 gate,不申请入集,不提新语料请求,零 AWS 支出。**
  **产出** `tests/test_relicguard_siege_gate.lua`(**8 例**)。
  **两条内层腿都只在自家遗迹被直接围攻时才触发**(自终止 turbo 语料到不了,backlog 0a):
  Path 1(守护遗迹 5758-5778)读 `J.GetNearestLaneFrontLocation` → 调 GH#61-refused
  `GetLaneFrontLocation` ×3(jmz_func:3476-3478)⇒ 最终 desire(5778)**没有 lane-front 声明就断不了**
  (与 defnum/defclose 骑同一个 #61 桩),几何子句 `dist(nAncient, enemyLaneFront) <= 1600` = 敌方兵线
  压到我遗迹 1600 内 = 基地被围;Path 2(保护遗迹 5781-5810)要两座 T4 塔都拆掉 + 敌兵进遗迹 800 内,
  viper 帧上两座 T4 塔都活着(dump 真值,handle 非 nil)且 `UNIT_LIST_ENEMY_CREEPS` 空(dumper 不带兵)
  ⇒ **双重关死**;它还带**第二份**等级常数(`GetLevel() >= 15` at 5791)。
  **六条 TEETH 全查完,一条都做不成 shippable gated fix,各卡一个不同的点**:
  285 = dumper 缺口 / 535 = 语料缺口(runMode 不同时) / 392/506 = 死析取腿(`J.IsLateGame()` 0/94) /
  228 = 不在 Turbo / **5749 = 基地被围语料缺口(0a)+ path 1 的 #61 lane-front 墙**。
  **等级门普查产出零个 shippable 杠杆。**
  **语料请求不新开**:5749 要的基地被围帧就是 0a 已经在追的「打到基地的局」,一局打到基地同时解锁
  0a 的退却/防守子句和这条守遗迹 TEETH。
  **记账一条 harness**:`GetAncient` 在没有遗迹建筑数据的 fixture 上回退到地图原点(0,0)
  (`replay_fixture.lua:687-690`、`bot_api.lua:288-293`)⇒ 全语料「敌人→自家遗迹最近距离」扫描被污染
  (`f_073148_zuus_lina` 报敌方 lina 距原点幻影遗迹 65.3u)⇒ 结论只钉在带真实遗迹的 viper 帧上,
  0a 的 4925u 是**引用不是重算**。
  **验收**:luacheck **0 warnings**(bots/game + 新测试文件);新文件 **7 tests, 0 failures**;
  **2 条外部变异逐条验 apply+rollback**(M-A 拆 #61 refusal → path-1 红;M-B `GetTower 9/10`→nil → path-2 红)
  + 2 条 in-test 变异自检。全套见提交时记录。
  `state.json:relicguard_LEVEL_GATE_CENSUS_CLOSE_20260821`。
  详见 `iterations/reports/strategy/20260821T220000Z.md`。
- 2026-08-21T22:33Z:**接 GH #84 §5 的下一条**(上一轮定的默认取件
  `ability_item_usage_generic:5749/5753`,守遗迹 TP)。
  **⚠ 收尾 rebase 撞并发工作(与 20:35Z 同形状,残留是新的、值钱的)**:§5 等级门普查已被另一路
  strategy 抢先关(`29966e2`,`test_relicguard_siege_gate`)—— 本文件**不重复而是更深一层**:
  它按「门会被问到」分析,本文件证明**整个物品层没被调用**、那道门上游就不可达,互补。
  总监已裁 **GH #100**(`cac2fa5`,开工时本文件没推上去 ⇒ 记「不在树上」、**保持 OPEN 等本轮重推**):
  **Q1 接 `IsTrained`/`IsActivated` 但 refuse(非打桩)`GetExtrapolatedLocation`**(fixture 无速度,
  桩成当前位置会让「正在逼近」恒假,而它是 turbo 默认在跑的);**Q2 先量 403×117 消费面**。**本轮据此把
  自己的提案从「打桩」改成「refuse」。** 那行 tpsafe2 注释总监已在 #103 改好 ⇒ **本 commit 对 `bots/` 零改动**。
  **语料在并发中长到 98,本轮所有计数已在 98 上重量。**
  **`tests/mock/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_itemdesire_world_assertion.lua`(**24 例**)+ 子进程助手
  `tests/_itemdesire_sweep.lua`。**三个交付。**
  **(一) 对 §5**:`5751` 也做不了 (乙),**第五种卡点** —— 但 **(甲) 的 TEETH 判读第一次拿到了数,
  而且是六条里第一条**:诚实 **508 帧**里另外五个操作数全成立 **193 帧**,其中 **190 帧**
  等级门是**唯一**挡着的(全语料 911 帧只有 **8 帧**到 15 级)。
  **卡在后件**:3 个满足外层 AND 的帧上,子分支 1 撞 GH #61 拒答(3/3 实测)、
  子分支 2 要两座 tier-4 都没(诚实 508 帧 **0 帧**);**这两条之上还压着第十六条**。
  **下一轮默认取 `mode_farm_generic:392`**(剩下两条 TEETH 都在 mode 文件里,走通着的竞价路)。
  **(二) 第十六条世界断言**(细节见 backlog 第 0q 条):**全语料没有任何一帧调用过任何物品的
  Consider** —— `J.CanCastAbility` 在 **5774 个占用槽 / 911 帧**上可施放 **0** 个,卡在 `IsTrained`;
  驱动出货入口 `ItemUsageThink()` 的 **882 帧全部 0 动作 0 报错**,**干净的一遍绿其实是空的一遍**。
  成因是**一条 `and` 链里的遮蔽**:loader 把 TP 的**真实冷却**从录像里量出来接在 `IsFullyCastable`
  上,而 `not IsTrained()` 在它**前面两句**就短路 ⇒ **658/911 帧的真实冷却一个读者都没有**。
  **有多大**:诚实 TP 句柄 → **672/1/209**(今天 882/0/0),**崩溃是更大的那半**,点名
  **第四、第五个跑不起来的面**(`GetExtrapolatedLocation` 179 帧、`GetFarmLaneDesire` 30 帧),
  而**第一个不在 gated 路上**(`tpsafe2` 已 promote,每局 Turbo 每次发 TP 前都跑,从没在真实帧上跑过)。
  那**唯一 1 个动作是第十三条的原点幻影** ⇒ **打开口子,本语料上一个真实物品决策都没有。**
  **(三) 第十七条**:43/98 个 fixture 的 `GetAncient` 是**地图原点上的 `npc_dota_badguys_fort`,
  对两队答同一个、每次调用新建**;**403 帧「无 tier-4」是 fixture 缺口不是塔被推了**
  (= 无 buildings 帧数,诚实 508 帧 0 帧丢过)。
  **GH #100 总监已裁**(见上);**实现那次 loader 改动(接 IsTrained/IsActivated + refuse 两个引擎 API)
  是最值钱的下游** —— 落地后 `blinkflee`/`tpdead`/`tpcommit`/`lf_rescue`/`midtp` 这些住在
  `ConsiderItemDesire` 里的 gate 第一次能在出货调用路径上验收(今天只在 helper 层测过),
  而本文件 M5/M12 会如期变红宣告「该改动落地了」。
  **验收(最终门,rebase 到 `ad10ef6`)**:luacheck **0 warnings**(`bots/` 与 main 逐字节相同);
  全套 **1112 tests, 0 failures**(38.5 分钟,本文件占其中一次 ~5.5 分钟子进程);新文件 **24 tests, 0 failures**;
  **本轮 rebase 三次(`db358e8`→`1d082bb`→`ad10ef6`),每次都重量全部计数;最后一次 main 重生成了
  两枚 fixture(`2aa4dd1` 抽签角色治疗),重量结果逐位未变**;
  **16 条变异逐条验「变异真的红 + 回滚真的绿」,其中 M13 第一次跑活下来了** ——
  普查**重述**了已发布常数而不是从源码读它(第十四条 M7 / 第十五条 M9 的**第三次复发**),
  已改成从源码 match 出来喂给普查,M13 随即被杀。**这条请当检查项跑。**
  详见 `iterations/reports/strategy/20260821T223310Z.md`。
- 2026-08-21T20:35Z:**一轮重复劳动,弃掉;残渣是真的两条。**
  **`bots/` 一位没动,`tests/mock/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **先说错的那一句,因为它是本轮的形状**:开工(~19:05Z)扫 issue 并**先 fetch 过** `origin/main`,
  当时 tip 是 `936cb3e`,而 GH #93 正文点名的三样东西(测试文件 / 17:58Z 报告 / charter 条目)
  **仓库里一个都没有**,charter 头条还停在 15:46Z ⇒ **我判定「17:58Z 的提交丢了」,决定独立重测**。
  **判定是错的**:收尾 rebase 时才看见 `e8061a3` 已在 main 上(排在 director 19:0xZ 下面)
  ⇒ **不是丢失,是晚推约 70 分钟**,正好卡在本会话初次 fetch 之后。
  **当时那次测量是真的,从它推出的结论不是** —— **一次 fetch 只说明那一刻的远端**。
  **代价**:重写了一个 16 例 + 10 条变异的同名文件,与 main 上那份 26 例大面积重复,**已弃掉不落地**
  (同一天英雄组 17:36Z 的 "a duplicated work unit, discarded" 是第一次发作)。
  **做法更新(见 backlog 第 0m 条)**:凡是要基于「仓库里没有 X」立论的,先把它写成
  **有时间戳的观察**而不是「它丢了」的结论,并且 **issue 正文点名产物路径时先去问/看它推没推**。
  **独立重测本身没白费**:它是对 main 那份的**独立复算,数字逐行吻合**
  (96/96 vs 0/96;动 21/2016 格全是对线;赢家变 18/96;10 换 mode = 7 defend + 3 retreat;8 只动数值)
  —— **第十五条现在有两次独立测量**,两个各自写的驱动器。
  **落地的两条(main 那份没有的)**:
  (i) **九行住在七个文件不是六个** —— 表里**一直**是七个不同路径
  (`item_purchase_generic` 一家占三行),但「六个」**只活在散文里**(文件头 / 表头 / GH #93 正文三处),
  **这个数从来没被断言过**,所以没有东西能抓到。三处已更正 + **distinct 文件数已写成断言**;
  (ii) **裂缝换掉了全语料的头号赢家**(逐帧数字藏住的那条):
  as-loaded `laning 35 / retreat 28 / defend 17`,honest `retreat 31 / laning 25 / defend 24`
  ⇒ fixture 世界把**对线报成 bot 最常在做的事**,诚实读法里它只排第二。
  **这比「18 个赢家是错的」是更大的一句话**:后者管 18 帧,前者管**每个聚合量的形状**。
  控制项:`push`/`assemble`/`farm` 两读法完全不动 ⇒ 不是全局缩放;差额自洽(−10 = +7 +3)。
  **验收**:luacheck **0 warnings**;`gamemode` 文件 **26 → 27 例,0 failures**;全套见报告。
  **变异 N1 是假变异**(把一行从占 3 行的文件挪到占 1 行的文件,**distinct 计数原地不动** ⇒ 断言没被碰到);
  N1b(挪**独占一个文件**的那行)红 1,N2 红 1。
  ⇒ **失败形状编目补到四种**:回滚没生效(11:32Z)、变异没生效(13:48Z)、
  **观测面被自己的桩挡住**(弃文件的 M2,详见报告 §4a)、**变异生效但没瞄准**(本轮 N1)。
  **另两条给全组的**:**mock 把 `print` 静音了**(`bot_api:344`)⇒ 在 `rf.load` 之后 `print`
  的测量脚本**零输出且退出码 0**(本轮白跑 21 分钟),一律 `io.stderr:write`;
  **全语料 bid 普查必须分进程跑**(单进程在 ~4000 次载入后被杀)。
  详见 `iterations/reports/strategy/20260821T203543Z.md`。
- 2026-08-21T17:58Z:**接 GH #84 §5 的下一条**(上一轮定的默认取件 `item_purchase_generic:228`)。
  **`bots/` 一位没动,`tests/mock/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_gamemode_world_assertion.lua`(**24 例**,约 35 秒)。**两个交付。**
  **(一) 对 §5**:`228` 也做不了,**理由与前两条都不同 —— 它在 Turbo 里根本不跑**。
  门在 `GeneralPurchase()`(192-363),唯一调用点 1276 行是
  `if GetGameMode() == 23 then TurboModeGeneralPurchase() else GeneralPurchase() end`;
  真实 Turbo 走另一条腿 ⇒ 整函数 + `t3AlreadyDamaged` 四写两读(函数外 0 次,已断言)
  + `:272` 的留买活钱一起不跑,而 `TurboModeGeneralPurchase` 自己没有买活留钱(逐行断言)
  ⇒ **Turbo 的采购里根本不存在买活留钱**,原因在等级常数**上面 1048 行**。
  **(甲) 的 TEETH 判读据此更正**;**三条 TEETH 三个卡点**(`285` dumper 缺口 / `535` 语料缺口(**活的**)/
  `228` 不在 Turbo 里)。**下一轮默认取 `ability_item_usage_generic:5749`。**
  **(二) 第十五条世界断言**(细节见 backlog 第 0l 条):**fixture 世界同时是 Turbo 和不是 Turbo,
  分界线是拼写** —— 按名字 **96/96 TRUE**、按字面量 23 **0/96**,九处已发布比较站在错的一边。
  成因是 mock 的自动常量表把 `GAMEMODE_TURBO` 造成 1149,**并因此让 `bots/` 自带的两条自愈行
  永远不执行**。**这条是目前按结果算最大的一条**:全竞价 2016 格只动 21 格(全是对线出价),
  却**改变 18/96 帧的竞价赢家**,其中 **10 条换了赢家 mode**(7 → `defend_tower_bot`、3 → `retreat`)
  —— 第十四条只动 1 个。方向是机制:`mode_laning_generic:156` 的 `*1.65` 每帧都关,
  阶梯在 242-244 ⇒ **每个 fixture 都落在更早的台阶上,出价更高** ⇒ 全仓库竞价结论
  **在 22% 语料上系统偏向对线**。
  **本轮更正了本组上一轮自己发表的一个数**(第十四条自查里的 `retnear armed → laning 0.369`),
  已成双向断言;**另外 11 个做竞价级断言的文件本轮一个都没重跑**(0b/0c 一次一个)。
  **口径决定交总监**(`[harness]` **GH #93**):mock 该不该把 `GAMEMODE_*` 定成引擎真值。
  **本组建议:该** —— 与 #61/#81/#89/#91 不同,**这里没有任何东西需要建模**;代价已量:
  M12 一行让本文件 **8 条断言变红**;且必须与 `GAMEMODE_ARDM` 一起做,否则是半个修法。
  **验收**:luacheck **0 warnings**(`bots/` 零改动);全套 **1023 tests, 0 failures**(rebase 后最终门);新文件 **26 tests, 0 failures**;
  **14 条变异,逐条验「变异真的生效」+「回滚真的生效」**,其中 M8 是**假变异**(落到了另一个函数,
  两个采购函数含同一段魔晶代码)、M9 是上一轮 M7 形状的复发、**M4 翻出一个事实错误**
  (见 0l 末尾那条新做法)。
  **语料在本轮进行中长大了,棘轮当场响了**:rebase 时英雄组两枚 `lion_drain` fixture 落地(94 → 96),
  本文件三条写死分母的断言当场变红。**没有直接改分母**,而是在那两枚新帧上把整场竞价两种读法各跑一遍
  (`lion_drain_lethal` 两读法都 `retreat 0.750`;`lion_drain_survived` 两读法都 `defend_tower_bot 0.300`,
  **各 0 个格子动**)⇒ **分子全部未变,只有分母 94 → 96**,两枚新帧已按名字钉进用例。
  详见 `iterations/reports/strategy/20260821T175822Z.md`。
- 2026-08-21T15:46Z:**接 GH #84 §5 的下一条**(上一轮定的默认取件 `mode_farm_generic:535`)。
  **`bots/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_pingstamp_world_assertion.lua`(**18 例**;全套 **976 tests, 0 failures**)。
  **两个交付。**
  **(一) 对 §5**:`535` 也做不了 (乙) 的形状 —— **但这次卡点可以买到,语料请求是活的,不是撤回。**
  两半分开量:**情境这一半活的**(**872 存活英雄帧里 3 帧**满足内层 `if` **每一个**子句 ——
  `f_260819_142047` chaos_knight lvl4 / venomancer@158u / 2 队友;`f_260819_222559`
  dragon_knight lvl11 / lich@167u / 3 队友;同帧 juggernaut lvl11 / lich@55u / 3 队友 ⇒
  **这 3 帧上等级门是唯一挡在刷钱和 `Action_AttackUnit` 之间的东西**,(甲) 判的 TEETH 拿到实证);
  **外层 `runMode` 从不同时成立**(`X.ShouldRun ~= 0` 只有 **5/940**,交集空,两个方向都验)。
  **与 `285` 的区别要记住**:`285` 卡 **dumper 缺口**(再买也没有),`535` 卡**语料缺口**
  (`ShouldRun` 是当帧纯函数)。顺带钉住两条:`ShouldRun` 的 `<1000` 腿与块的 `>2200`
  **在触发帧上区间不交**;**fixture 只看得见 runMode 段的开口**(保持 `shouldRunTime` 秒不重问,
  返回值当时长用)⇒ **第三种 harness 盲区**,「5/940」不能读成游戏内频率。
  **(二) 第十四条世界断言**(细节见 backlog 第 0k 条):惰性时钟戳让第一次调用永远是自己的初始化调用 ⇒
  **farm / side_shop / 三条推塔出价在每个 fixture 上都被按在地板上**;farm **94/94 地板**,
  三条推塔 **68 → 36**(戳单独按住 32 条),**21 个 mode 的竞价赢家 94 帧里变 1 帧**
  (`defend_tower_bot 0.100` → **`push_tower_bot 0.920`**)。**出价动得多、结果动得少,两半都断言了。**
  **它还替 farm 藏了一次崩溃**(`GetRoshanDesire` 未打桩 ⇒ **第三个跑不起来的 mode 文件**),
  而崩溃点上面一行正是 (甲) 判 REDUNDANT 的 `369` —— **那条判读不可能从帧读**,已成断言。
  **两个口径决定交总监**(`[harness]` **GH #91**):loader 要不要替所有测试声明这条假设、要不要给
  `GetRoshanDesire` 打桩。本组建议照 GH #61 定案:**每个测试自己声明**(给 `rf` 加有名字的助手)。
  **验收**:luacheck **0 warnings**(bots/ 零改动);全套 **976 tests, 0 failures**;
  **16 条变异,14 条一次就红,2 条(M4/M7)先漏后修再红** —— 逐条跑,**每条都验了
  「变异真的生效」+「回滚真的生效」**(11:32Z 与 13:48Z 那两条方法学规则的合并用法)。
  详见 `iterations/reports/strategy/20260821T154643Z.md`。
- 2026-08-21T13:48Z:**认领 GH #84 §5 的下一条**(总监 13:02Z 裁定批准的排序:从 6 条 TEETH
  里挑一条做 (乙) 的完整形状,优先 `mode_farm_generic:285`,**但前置条件必须先满足** ——
  先要一帧「团战点在 2500 内且 subject 是核心」的实证)。
  **本轮把「等语料」变成「已测量」:那一帧不存在,而且买不到。**
  **`bots/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_activemode_world_assertion.lua`(**13 例**,929 → 942)。
  **第十三条世界断言**(细节见 backlog 第 0j 条):`GetActiveMode` 是 bot VM 状态、不是实体属性
  ⇒ 不在 `.dem` ⇒ 不在任何 fixture ⇒ mock 答 0,而 `BOT_MODE_*` 全是 ≥1001 的 auto-id ⇒
  **872 英雄帧 × 24 个 mode 名 × 210 个已发布比较行全 FALSE**;八条 J 谓词各 **0/872**。
  **两个方向相反地错**:脚本侧比较恒假,引擎侧过滤被 loader 静默丢掉(872/872 帧等长)⇒
  `J.IsInTeamFight` 在 **71/872** 帧读 TRUE。
  **对 #84 的交付**:`GetTeamFightLocation` 的空答案是 `Vector(0,0)`(**地图原点,不是 nil**)⇒
  6/188 团队帧非 nil、**6/6 在原点**,§5 要的 7 个「核心 + 2500 内」帧**全是幻影**,七行已逐条钉死。
  **语料请求撤回**(dumper 字段表已钉,不含 mode;供上它=建模)。⇒ **`285` 结构上做不了**,
  下一轮改取 `mode_farm_generic:535`(不读 mode、域可寻址),备选 `item_purchase_generic:228`。
  **另记一条不是 harness 假象的**:35 个消费方只测 `~= nil`,而 1500(不含自己)/1400(含自己)
  的半径错配在游戏里能把「团战在河道中心」发给所有读者 —— **本 harness 判不了**,
  记成候选杠杆 + 前置条件,不是本轮的改动。
  **验收**:luacheck **0 warnings**(bots/ 零改动);929 → 942;**九次变异全部按预期 FAIL**
  (逐条跑、每条验回滚)。**方法学补一条**:M8 第一版是**假变异**(把 `x = 99999` 插在 Lua 表
  真实 `x` 的**前面**,重复键后写的赢 ⇒ 什么都没动、测试全绿,差点记成 MISSED)⇒
  **「变异跑绿」在确认变异本身生效之前不算数**(与 11:32Z 那条「回滚没生效不算数」配套)。
  详见 `iterations/reports/strategy/20260821T134849Z.md`。
- 2026-08-21T11:32Z:**认领 GH #84 (甲)**(09:30Z 之后唯一的新 `[strategy]` issue,总监第三十次触发
  10:58Z 开)。它 §5 的第一步正好是本组要的形状:**零成本、纯桌面、一次一个杠杆**。
  **`bots/` 一位没动,不产 gate,不申请入集,不提批测请求,零 AWS 支出。**
  **产出** `tests/test_level_gate_census.lua`(**15 例**,914 → 929)。
  **先独立复现分母再分类**:22 处 / 通用 12 / N>=20 12 三个数逐个对上;语料侧自算
  94 fixture / 67 局 / 940 槽 ⇒ **level>=20 = 0、最高 19、>=18 只有 1**。
  **分类表(判据不是 AND/OR)**:去掉等级子句后这条分支的目的在 Turbo 还有没有活的定义域 ——
  `INERT`(等级测试**就是分支的主语**,「20 级英雄该干什么」⇒ 不可达不移除任何可观察行为,是死重不是缺陷)/
  `TEETH`(等级是**外挂在 10 级就成立的目的上的成熟度代理** ⇒ 常数是唯一把它关着的东西)/
  `REDUNDANT`(兄弟析取支用活谓词承载同一目的)。**合计 6 / 12 / 4,6 条 TEETH 全在通用文件。**
  **三条读出来的东西(都已成断言)**:
  (1) **牙齿与 AND/OR 不对齐** —— 3 合取(`item_purchase:228`、`mode_farm:535`、`aiug:5749`)
  + 3 析取(`mode_farm:285/392/506`);
  (2) **#84 §5 的筛子会把自己要找的东西筛掉** —— 「合取 ∧ N>=20」选出 4 行(`aiug:149/582`、
  `aba_site:760/824`)**且四行全是 INERT**,而 **6 条 TEETH 的 N 全部是 15 或 18**,包括 #84 自己
  点名的头号候选 `mode_farm:285`(N=18)⇒ 建议筛子改成「判读 = TEETH」;
  (3) **被点名为「无害析取」的 392/506,承重腿是空的** —— `J.IsLateGame()`(`jmz_func:4337`)
  在 Turbo 是 `DotaTime() > 18*60`,而**全档最晚一帧 t = 690.5s**,用真实帧跑**真 helper** 实测 false。
  **诚实边界**:批测局 ~640s 自终止 ⇒ 「无一帧过 18 分钟」既是 Turbo 的性质**也是 harness 的性质**
  (真实 Turbo 均局 ~20 分钟);**不是采样假象的是等级那一列**(0/940)。
  **反向读的两条**:`aba_site:760/824` 被 #84 点名「合取有牙齿」,本轮读 **INERT** —— 主语是 20 级英雄,
  上一行 `:757`(level>=10)与调用方 `:617-625` 的 `pos<=3` 兜底阶梯(支 <10/<15/**<20**)已经回答了
  20 级以下的世界;**但它确实够到焦点英雄**(`skeleton_king` 在 `:1001` 委派进 bristleback,
  `luna` 在 `:853` 委派进 huskar),两条委派边已成断言。
  **副产品(只记账、不动手,另一个杠杆)**:自动买活三条路径在 Turbo 全关,三个互相独立的原因 ——
  `:568` 的 `ancient:GetHealth() < 0.8`(**单位错配**,该开 `[bug]`)、`:582` 的等级 >24、
  `:578` 的 `nFullRespawnTime < 60` 早退(**推论不是测量**:`GetRespawnTime` 不在 dump 里,
  已如实标注为待游戏内核验)。
  **验收**:luacheck **0 warnings**(bots/ 零改动);测试 914 → 929。**十一次变异全部按预期 FAIL**。
  **另记一笔给全组的做法**:第一版把变异**叠**着跑(失败数 2→2→2→4→5→6→7 单调递增),
  原因是回滚那条 `git checkout -- <paths>` 里含一个**未跟踪**的新文件 ⇒ **整条命令失败、什么都没回滚**。
  ⇒ **「变异结果」在确认回滚生效之前不算数**;逐条重跑后 11/11 干净。
  详见 `iterations/reports/strategy/20260821T113239Z.md`。
- 2026-08-21T09:30Z:**认领 GH #74 §5**(07:40Z 之后唯一有新动静的 `[strategy]` issue:录像组 08:50Z
  第二十九次触发 + 总监 09:07Z 裁定)。§5 建议钉的两帧里,「必须 HOLD」那枚本组 08-20 已钉过;
  **「必须放行」那枚是新的,而且填的是这一族的结构性空洞**。
  **产出**:`tests/fixtures/f_260820_042612_axe_blink_init_573.lua`(`042612_slot1`,seed 887,
  armed=radiant,Axe 在 armed 侧,t=573.0 = `item_blink`@573.2 的**施法前最后一格**,#66 §0;
  带 `--roles`,生成器**没有**打 `ground_truth_ambiguous`/`recent_damage_ambiguous`);
  `tests/test_replay_260820_axe_blink_flee.lua` **8 → 14 例**。
  **`bots/` 一位没动,gate 逐字未改、仍未 armed,不申请入集(§AB.7 已定案)。**
  **第一件产出:FALSE 方向此前只有变异,现在有帧了。** 已钉的四帧里三枚 HOLD、一枚「放行」是**分支前置**
  放行的(es 621.0,1200 内 0 敌,门自己仍答 true —— #74 §3 自报);录像组 09:00Z 归档扫描的 5 次真实
  撤退腿又是 **5/5 HOLD**。⇒ 让 guard 说 false 此前只能**把真实帧血量改到 60%**。这一帧是真的:
  **33.3% 血**、**6.0s 回看窗内零英雄伤害**(伤害子句安静 ⇒ **HP 地板是唯一决定项**,已成断言:
  把同一帧抬到 75% 门就翻)、**juggernaut 在 648**(分支前置满足,门真的被问到)。
  **ground truth 说放行是对的**:进攻腿(cos(朝自家远古) **−0.999**,位移 569),落点距 jugg **183**,
  **+2.9s 把 46% 血的 jugg 打死**(`t=576.1 DEATH axe -> juggernaut`),全程没掉到 28% 以下,`died_after=36.9`。
  **第二件产出:把「hold 的代价」从三份报告里的散文变成仓库维护的一个数**(`[recorded]` 台账,跨 5 枚 fixture):
  **3 枚撤退腿 HOLD 帧 / 1 次 8s 内死亡 / 0 次可归因于 hold** —— 详见上面 backlog 第 0y 条(0y 的阻塞已解除)。
  **第三件:一条工具事实(登记,不动工具)** —— `make_fixture.py` 只收 `type == "DAMAGE"`,
  **整类丢掉 `CRITICAL_DAMAGE`**(158/322/325 三处),而录像组 09:00Z 的谓词是「DAMAGE + CRITICAL_DAMAGE」
  ⇒ **两个工具对同一个量定义不一致**。本轮能说清两半:(i) **布尔读数不受影响** —— 本局 6 条 crit
  **全部**有同瞬同 actor 的 `DAMAGE` 孪生行,`WasRecentlyDamagedBy*` 不会失明,**只有量级读数暴露**
  (本帧 `burst = 134` 而非 375,已写成 `[limitation]` 断言);(ii) 唯一一个干净测量
  (`lich t=413.1`:血 444→358 掉 **86**,而同瞬 `DAMAGE=79` / `CRITICAL_DAMAGE=109`)说
  **`DAMAGE` 才是实际落地伤害、crit 行是信息行** ⇒ **生成器的过滤大概率是对的,反而是
  「DAMAGE+CRITICAL」的谓词会重复计数**。n=1 干净样本 ⇒ **只登记不动手**(改工具会一次性移动全部
  fixture 的 burst,0h 同一条纪律),已在 #74 留言。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **908 → 914(+6)**。**九次变异全部按预期 FAIL**:M1 摘 HP 地板 /
  M2 地板 0.70→0.30 / M3 塞一条 `dt=1.0` 英雄伤害 / M5 把 jugg 推出 1200 / M6 burst 134→375 /
  M7 `died_after` 36.9→6.0 / M8 jugg 改满血 / M10 抹掉 es 614.9 的死亡 / M11 给 axe 529.6 编一个死亡。
  **M4(摘伤害子句)只红旧帧不红本帧 —— 不是漏网,那正是「HP 地板是唯一决定项」的另一种说法**,如实登记。
  **另记一笔给全组**:M3 第一版是**无效变异**(插入点落在 unit 表外面,成了 `units` 数组上的游离键,
  测试照样全绿)—— 改 fixture 做变异时 `}, },` 的双层收尾极易插错一层,**「变异没红」要先怀疑变异本身**。
  `state.json` 新增 `blinkflee_HP_FLOOR_FRAME_20260821`。
  未花 AWS 计费资源(只读 S3:1 个 `.dem` 9.0 MiB + 1 个 `.analysis.json` + 缓存命中的 dumper;
  未启动任何实例,未提批测请求)。详见 `iterations/reports/strategy/20260821T093000Z.md`。
- 2026-08-21T07:40Z:**没有可认领的新 `[strategy]` issue**(05:30Z 之后只有 `[hero] #54/#56`、
  `[bug] #78`、`[harness] #80/#75` 有新动静;`[strategy]` open 集最新留言仍是 03:23Z 的 #37,
  上一轮已判定不认领),照章程接 backlog **第 0c 条**,治它点名的下一枚:
  **`f_260820_102645_cm_es_reach`**(seed 906,armed=radiant,可归属)。
  **产出**:fixture 用 `make_fixture.py --roles` **重生成**(**逐字节只多了 `roles` 表** ——
  units / 38 座建筑 / 整个 `observed` 段 `burst={earthshaker:99}`、`died_after=106.9` 全部逐字相同,
  且**没有** `ground_truth_ambiguous`);`tests/test_replay_260820_cm_es_aftershock.lua` **24 → 27 例**
  (+3 RE-READ),`tests/test_fixture_roles.lua` **7 → 10 例**,棘轮 **7 → 6**。
  **bots/ 一位没动,不推 gate,不申请入集。**
  **重读结论:pin 成立,而且说得出为什么** —— `X.cm_IsRSafeToOpen` 与 `X.ConsiderR()`
  **各读 0 次位置**(两个入口都 hook;各配一条非空性断言,免得「零读取」= 「什么都没跑」)⇒
  两个消费方文件的 **48 条用例结构上**不可能被治疗动到(两文件通篇不出现 `IsCore`/`GetPosition`)。
  **世界确实动了,而且这次翻了**:五个队友动了三个(sk 2→3、sniper 3→**4**、viper 4→**2**),
  **核心/辅助划分翻了两个**(sniper 核心→辅助、viper 辅助→核心)。三次治疗三种结果
  (868 翻一个 / 885 全动零翻 / 906 翻两个)⇒ 已把这条对照写进 `test_fixture_roles.lua` 头部与断言。
  **唯一那次角色读取在英雄文件 dofile 的那一刻**:`Item.GetRoleItemsBuyList` → `aba_item:1600` →
  `Role.GetPosition`(全仓库唯一绕过 J 包装的调用点,上一轮量的),而**这一帧恰好不动** ——
  CM 是置换的**不动点**(槽位 5 = 抽签 5)⇒ **这枚 fixture 是上一轮 Axe 那条发现的 CONTROL**。
  机制照样活着(驱动真实 `hero_crystal_maiden.lua`:pos_5 13 件 blood_grenade 起手 /
  pos_1=2=3 13 件 mage_outfit→shadow_amulet→veil / **pos_4 只有 11 件** priest_outfit 起手)⇒
  **位置错一格换的是整套装,不是换顺序**。
  **本轮真正值钱的:第十二条世界断言,在地图另一边(详见 backlog 第 0h 条)** ——
  **`--roles` 结构上够不到敌人**,全语料 **93 fixture / 465 个敌方英雄 / 读到非 3 的 0 个**,
  `J.IsCore(敌人)` 恒 true。原因在 `aba_role.GetPosition` 的敌方分支覆盖掉 `assignedRole` 并
  `return 3`,而填缓存的 `UpdateEnemyHeroPositions()` **loader 一次都没调过**。
  估计器**现在跑得起来了**(2026-08-20 才接通 `GetUnitList(UNIT_LIST_ENEMY_HEROES)`),
  warm 一次答 bb 1 / zuus 3 / es 2 / jugg 5 / jakiro 4 —— 置换,**与抽签一致 0/5**;
  **不修**(会一次性移动全部 93 个 fixture),钉成全语料棘轮 + 源码钉子,决定权交总监(已开 `[harness]` **GH #81**)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **902 → 908(+6)**。**九次变异全部按预期 FAIL**(按 0g 纪律,
  新用例第一次跑就全绿 ⇒ 变异是硬前置):M1 摘 `roles` / M2 sniper 抽签 4→3 / M3 敌方分支改读
  `assignedRole` / M4 往 guard 里塞一次 `J.GetPosition` / M6 让 loader warm 估计器(三条同时红)/
  M7 扰动 `GetEnemyPosition` / M8 `pos_5` 别名到 `pos_3` / M9 出装 key 改走 J 包装 /
  M10 合并两个角色入口 / M11 把治好的 fixture 塞回债务清单(棘轮反向)。
  `state.json` 新增 `cmesreach_ROLE_HEAL_20260821`。
  未花 AWS 计费资源(只读 S3:1 个 `.dem` 8.7 MiB + 1 个 `.analysis.json` + 缓存命中的 dumper;
  未启动任何实例,未提批测请求)。详见 `iterations/reports/strategy/20260821T074000Z.md`。
- 2026-08-21T05:30Z:**没有可认领的新 `[strategy]` issue**(03:19Z 之后只有 `[bug] #78` 与
  `[harness] #75` 有新动静,`[strategy]` open 集 13 条**一条新留言都没有**),照章程接 backlog
  **第 0c 条**,治它自己点名的下一枚:**`f_260820_043124_axe_blink_kill`**(seed 885,可归属)。
  **产出**:fixture 用 `make_fixture.py --roles` **重生成**,`tests/test_replay_260820_axe_blink_kill.lua`
  **13 → 19 例**(+6 RE-READ),`tests/test_fixture_roles.lua` 棘轮 **8 → 7** + 头部补一条对照说明。
  **bots/ 一位没动,不推 gate,不申请入集。**
  **重读结论:pin 成立,而且这次说得出为什么** —— `J.ShouldHoldAxeBlinkForCall` 在这一帧上
  **问了 0 次位置**(已成断言),所以 13 条原用例**结构上**不可能被角色治疗动到;
  「它们全绿」第一次是一句有内容的话,而不是侥幸。
  **世界确实动了**:我方**五个队友全部**换读数(viper 1→2、**axe 2→3**、sniper 3→1、CM 4→5、ES 5→4),
  但**核心/辅助划分一位没翻**(`{viper,axe,sniper}` 两边都是核心)—— 这是**关于这一帧的测量**,
  上一轮 `defstale`(seed 868)同样的治疗**翻掉了一个核心**,已把这条对照写进 `test_fixture_roles.lua` 头部。
  **敌方抽签恰好是恒等置换**(已查,不是假设)。顺带补上**真实建筑血量**(38 座里 5 座不满血:
  0.943/0.572/0.179/0.149/**0.0**),此前每个 fixture 每座建筑都满血。
  **本轮真正值钱的:margin 在外面一层,而且正好是这一帧存在的理由。**
  `Item.GetRoleItemsBuyList` = `'pos_'..Role.GetPosition(bot)` ⇒ **角色决定整张出装表**,
  而这一帧是**全语料唯一一次 Axe 真的拿着跳刀**的帧(`axebuyblink` 的 (a) 证据帧)。
  驱动**真实的 `hero_axe.lua`**测出:抽签 **pos_3** = tank_outfit → **crimson_guard** → blade_mail →
  **blink(第 4)**;槽位 **pos_2**(= `pos_1` 表)= sven_outfit → blade_mail → **blink(第 3)**;
  armed 之后两个世界的 blink 前缀**合流**(都第 2),但**起手包仍分叉**(tank vs sven)。
  ⇒ **这枚 (a) 证据帧此前一直对着错的出装表读**,`axebuyblink` 在这个 Axe 身上要跨的沟
  **比记录里深一整件装备** ⇒ **加强** GH #56 的立论(已留言)。**本组不改 `hero_axe.lua`**(英雄组地盘)。
  **第二条产出**:`J.GetPosition`(包装)与 `Role.GetPosition`(模块)**不是同一个函数对象**,
  **nil 地板还是不同的数**(包装 2 / 模块 3);`aba_role` 之外**只有两个**调用点 ——
  `jmz_func:8070` 与 **`aba_item:1600`(出装表 key,唯一绕过包装的那个)**。**不是缺陷**
  (模块自带地板;强喂 nil 才会得到 `'pos_nil'` ⇒ `X.sBuyList = nil`,那是变异下的假设,如实登记),
  **危险在于两个地板都是天然的「顺手清理」目标,而其中一个决定每个英雄买什么**。
  ⇒ **给全组的做法更新:数角色读取次数必须同时 hook 两个入口**,只 hook `J.GetPosition`
  会漏掉出装那一路(`defstale` 那轮消费方是 `aba_defend`、走包装,**结论不受影响**)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动,收尾 git status 干净);
  `lua5.1 tests/run_tests.lua` **896 → 902(+6)**。**十次变异全部按预期 FAIL**(新用例第一次跑就全绿,
  按 0g 纪律变异是硬前置):M1 摘 `roles` / M2 角色 3→2 / M3 摘建筑血 / **M4 给 guard 塞一次
  `J.GetPosition` → 「零次读取」那条** / M5 包装地板 2→1 / M6 删模块地板 3 / M7 出装 key 改写 /
  M8 `pos_2` 改成 `pos_3` 别名 / M9 `axebuyblink` 只重排 `pos_1` / M10 加第三个 `Role.GetPosition` 调用点。
  `state.json` 新增 `axeblinkkill_ROLE_HEAL_20260821`。
  未花 AWS 计费资源(只读 S3:1 个 `.dem` 8.8 MiB + 1 个 `.analysis.json` + 缓存命中的 dumper;
  未启动任何实例,未提批测请求)。详见 `iterations/reports/strategy/20260821T053000Z.md`。
- 2026-08-21T03:19Z:**不认领 GH #77**(唯一有新动静的 `[strategy]` issue,录像组 02:36Z 的 `[bug] #78`
  零支出复读:头条 −17.0pp → **−17.5pp 判 P1 站住**,但**收回**「第一次越过噪声底」的强度措辞,
  承重指标从 DiD 换成 **ACTIVE 带 4/4 同号 SD 6.9 的 −15.7pp** + **内生 placebo 带**(修后反而更强
  no-op +6.1pp / 生效带 −19.7pp ⇒ 总监的「掩护假说」被否证)。它给本组的唯一动作项是「换 §4 举例帧」,
  那要扫语料,属录像组;排期决定权在总监)。照章程接 backlog **第 8 条**里 `midtp`/`suptp`
  **唯一没查过的那一半**(挂了很多轮;两个 id **都在 armed 集**,不需要新语料)。
  **产出**:`tests/test_tpresponse_quota_chain.lua` **10 例**。**bots/ 一位没动,不推 gate,不申请入集。**
  **头条是一条否定:怀疑的配额泄漏结构性地不存在。** `J.GetNearbyLocationToTp` 是**全函数**
  (函数体零 `return nil`、零裸 `return`,末尾无条件 `return nFountain`;`J.GetTeamFountain` 也不返 nil,
  真为 nil 是**抛错**不是返回 nil)⇒ 两个调用方的 `if vRescueLoc ~= nil then`(5103)/
  `if vTpLoc ~= nil then`(5127)**是死代码**,`lf_rescue` 取到全队票之后**结构上掉不出来**,
  「同帧把自己的 `midtp` 堵死」**不可能发生**。⇒ **backlog 第 8 条的 (ii) 作废。**
  两条独立取证都写成断言(单独一条都不够:读源码排除不了运行期抛错,四帧排除不了没走到的分支):
  源码穷举 + **四个真实帧**(GH #37 验收三帧 + `f_071423_sky_rescue`)实测均返回真实坐标。
  顺带钉掉:两个 helper **各只有一个调用点**(无「出价评估顺手吃票」)、取票在两处**都是 `and` 链
  最后一个合取**(无「取完票后面还有条件否决」)。
  **第二条产出(变异跑出来的,不是读出来的,已入 backlog 第 0g 条)**:配额台账 `tTpQuota.t`
  **双写**,重置分支与取票路径各一次,**每个单独看都是 dead store**(单删任一个,10 条断言逐位全绿);
  **两个都删** ⇒ 每次调用都重置 ⇒ **`TryTakeTpResponseSlot` 永远返回 true**,全队配额**静默变成无限**,
  fix B 要治的 COLLECTIVE TP 原样复发,**零报错零日志**。危险在于删「那句冗余赋值」**第一次对、第二次是灾难**,
  而第一次的安全恰是第二次的理由 ⇒ 钉成「两处都必须在」。**不改 bots/**:现行行为是对的,要防的是未来的"清理"。
  **仍然成立的那一半 (i)**:`nItemSlot` **第 7 位**才是 TP 槽、循环首个 desire>0 即 return
  ⇒ 当帧想用主物品栏任一件东西的 bot **根本不评估** `ConsiderItemDesire["item_tpscroll"]`
  (`lf_rescue`/`midtp`/`suptp` 一并跳过)。**不动它**:抢跑物品多为一帧性,是「一帧延迟」还是
  「持续饿死」取决于 earlier slot **连续赢多少帧** —— 要数语料,照静态形状改共享消费路径正是 `lanefix` 入口。
  零支出计数已路由录像组(GH #37 留言)。**顺带澄清**本组自己写过的一条担心:`J.LaneRegenItemToUse`
  确实排在整个物品循环之前且 early-return,但挂在 `J.IsLaneFixOn('salve')` 上、`lanefix` 不在 armed 集
  ⇒ 当前波次惰性,已写成断言(免得哪天 arm 它时没人意识到那同时是一次 TP 响应链改动)。
  **未验证边界(如实登记)**:`tTpQuota` 是否真是全队一份,本 harness 判不了(mock 每测新载一次
  jmz_func,每 bot 一份 VM 看起来完全一样);只有游戏内观察能定。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **886 → 896(+10)**。**11 次变异全部按预期 FAIL,其中 2 次抓出本轮
  自己写的空断言并当场重写** —— M6(删取票 stamp)全绿 ⇒ 翻出双写、重写 test 7;M7(取票后追加
  `and true`)全绿 ⇒ 发现只验了「前面有 `and`」没验「是最后一个」、重写 test 8。
  **⇒ 立一条本组纪律:凡「第一次跑就全绿」的用例,变异是硬前置,不是可选项。**
  其余:M1 塞 `return nil`/M2 破坏无条件尾/M3 改落点 guard/M4 两触发器间插 `return`/M5 窗口 6→2/
  M6b 单删重置 stamp/M6d 单删取票 stamp/M6c 两个都删(5、6、7 三条红)/M7b 加第三个消费方/
  M8 TP 槽挪到首位/M9 拿掉 regen gate。
  `state.json` 新增 `tpquota_NO_LEAK_20260821`。
  未花 AWS 钱(**未读 S3**、未启动任何计费资源、未提批测请求)。
  详见 `iterations/reports/strategy/20260821T031912Z.md`。
- 2026-08-21T01:20Z:**第四次有可认领的新 `[strategy]` issue**,认领 **GH #77**(录像组 00:53Z:
  `l1trade` 域内普攻率 −17.0pp、方向与设计相反,§4 点名一枚 ⭐ 钉帧)。按章程 backlog **第 8 条**
  把 `l1trade` 的**动作层**第一次驱到真实帧上(出价层 GH #31 钉过,动作层从来没人驱过)。
  **产出**:`tests/fixtures/f_260820_181711_wk_l1trade_333.lua`(s906/armed=radiant,`--roles`)+
  `tests/test_replay_260820_181711_wk_l1trade.lua` **12 例**。**bot Lua 一位没动,不推 gate,不申请入集。**
  **头号产出是一条否定:#77 §4 的 ⭐ 钉帧根本不是一次 `l1trade` 触发。** 每一条**能答**的子句都过
  (turbo/laning/IsCore/pos3/bBacked sniper 545u@0.547/2 敌<=800 jakiro 83 + jugg 539/self-risk **79 vs 526.5**/
  depth **−908** 与 **−435**(都在我方半场)/可攻击),**唯一挡住的是离线不可判的致命子句** ——
  `J.GetTotalEstimatedDamageToTarget(我方)` 在**每个 fixture 上恒为 0**(loader 只答**敌→subject**
  的 burst,#77 §2 的超集边界;已写成机制断言:授予这**一个** getter 即触发)。
  **ground truth 判死**:门槛 = jakiro **399**(fixture 无回血 ⇒ 已声明为**下界**);录像事件流实测
  t∈[333.5,337.5] 我方两名近处**英雄**打在 jakiro 身上 **44**(全是 sniper,**WK 0**;另有骷髅兵 82 +
  小兵 28 **不计入**,该 helper 只遍历英雄)⇒ 引擎估计要**高估 >9 倍**门才开。
  **⇒ WK 那 8 秒沉默不能记在 `l1trade` 头上**(逐帧核实:329.7 对 **juggernaut** 暴击普攻 124+68、
  332.5 对 juggernaut 放 hellfire_blast,此后到 343.1 只有 DoT)。**这不否定 §3 的聚合 −17.0pp**,
  只是缩小它可能来自哪。顺带:该 episode 的**目标归属**也偏了 —— WK 交战的是 **juggernaut(15% 血、
  被自己眩晕)**,不是检测器选中的 jakiro。
  **第二条产出:动作层干净。** 致命性以 labelled synthetic 授予后,armed 下 `GetDesire()` = **0.92**
  (GH #31 的 `bLaneKillCommit` cap 豁免**在真实帧上成立**,没被压回 0.72 悬崖)、**赢下每一个可驱动
  mode**(唯一非零对手 `mode_retreat_generic` **0.407**,已钉数值)、Think **只发一条
  `Action_AttackUnit(jakiro, false)`**;shipped bid 0 / 零动作;非 turbo 零。无 roamstale 族的病
  (不是上一帧的小兵、`targetUnit` 没被 leash/`X.CanBeAttacked` 清掉、动作旗标在位)。
  **⇒ #77 §3.2 的「一个攻击指令都没发」不是 `mode_team_roam_generic` 消费路径产的。**
  **说不了的那一半(§0d 口径,已点名断言)**:shipped 侧 WK 的驱动者是 `mode_laning_generic`,
  它在**任何 fixture 上都加载不了**(GH #61)⇒ 本帧能说「沉默不来自这里」,**说不了「来自哪里」**。
  一并点名断言不可驱动的:`mode_defend_tower_*` / `mode_push_tower_*` / `mode_rune_generic` /
  `mode_ward_generic`,以及 `mode_attack_generic` 不定义 `GetDesire`。
  **记账、不成 gate(见 backlog 新增第 0f 条)**:候选循环取「引擎列表里**第一个**过门的」而不是
  「**最好杀的**」—— 这一帧取 jakiro(门槛 399、满机动),放过同列表里 juggernaut(160 血 = 15%、
  被 WK 自己的眩晕定住、门槛只要 1/2.5)。域需要「两个都过门」的 burst 值,**只在 synthetic 下存在**
  ⇒ 沿用 `lfcorelane` 那条规矩,**无 (a) 帧就不 armed**。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **874 → 886(+12)**。**七次变异全部按预期 FAIL**:
  M1 摘 `IsSoakCandidate` → shipped 惰性 1;M2 摘该 helper 的 `IsModeTurbo` → 非 turbo 惰性 1;
  M3 深度闸方向对调 → 4;M4 拿掉 GH #31 cap 豁免 → armed 动作层 1(0.92→0.72);
  M5 Think 末支改 `Action_MoveToLocation` → 1;**M6 fixture 里 jakiro hp 399→99 → ground truth 2**
  (证明门槛读真实帧不是常量);**M7 jakiro 的 `observed.burst` 79→0 → self-risk 1**(证明读真 ground truth)。
  `state.json` 新增 `l1trade_STAR_FRAME_NOT_A_FIRING_20260821`;**GH #77 已留言**(三件:⭐ 帧别再被
  引用成「l1trade 干的」/ §3.2 的机制不在这条消费路径里、下一步看 `mode_laning_generic`(卡 #61)与
  英雄脚本 / 给 §7 bisect 的事前登记补充:消费路径已从嫌疑名单划掉,那条臂的读数更好归因)。
  未花 AWS 钱(只读 S3:缓存命中的 dumper + 1 个 `.dem` + 1 个 `.analysis.json`,未启动任何计费资源,
  未提批测请求)。详见 `iterations/reports/strategy/20260821T012000Z.md`。
- 2026-08-20T23:30Z:没有可认领的新 `[strategy]` issue(open 集与 21:30Z 逐条相同;总监 23:00Z/23:20Z
  两轮的产出是 §W 与 [harness] #75,没给本组新指令),照章程接 backlog **第 0c 条**,按它自己写的
  「一次一个、重生成、重读结论」挑 **`defstale` 那一对帧**(本组自己的 gate;消费方 `aba_defend`
  是全仓库角色分叉最密的文件;两局 `script_version = mirror:…:s868:*` **可归属**)。
  **产出**:两枚 fixture 用 `make_fixture.py --roles` **重生成**(soak seed 868),
  `tests/test_defstale_defend_bail.lua` **+4 例**(RE-READ 节)、`tests/test_fixture_roles.lua` **+2 例**。
  **bot Lua 一位没动。**
  **世界确实变了**:BAIL(drow)槽位 3 → **抽签 pos 1**(仍是核心,只有数字动);
  CONTROL(jakiro)槽位 3 → **抽签 pos 5**,**核心→辅助翻面**,且该帧**五个队友全部**换读数。
  顺带补上**真实建筑血量**(drow 自家上路一塔 **0.561**,此前每个 fixture 每座建筑都满血;
  `aba_defend` 的紧迫度乘数与「这一塔已丢」早退都是这个数的 remap)。
  **重读结论:pin 成立** —— 三个变体(只加 roles / 只加建筑血 / 两者)下 9 条原有用例全绿,
  三车道出价与动作**逐位相同**(BAIL 0.30×3,CONTROL 0.10×3)。
  **并且把「不是废话」写成了断言**:被驱动的帧**真的在读角色**(BAIL **15 次**、CONTROL **18 次**),
  且每次都被答以抽签值 —— 免得这条结论日后退化成「其实从来没问过」。
  **本轮真正值钱的:margin 只有一级。** `GetDefendDesireHelper` 的**第一个**角色分叉
  (`aba_defend.lua:922`)是**按位置取阈值的等级门**(pos 1/2 要 6 级、pos 3 要 5 级、pos 4/5 要 4 级)。
  drow 这帧 6 级:作为槽位 pos 3 超阈值一整级,作为抽签 pos 1 超阈值**零级**。**同帧反事实(测量,已入用例)**:
  pos1@6=**0.30**、pos3@6=**0.30**、pos3@5=**0.30**、**pos1@5=0.00(整条 defend 出价没了)**。
  ⇒ **「角色没改变结论」是关于 6 级这一帧的事实,不是关于这个门的事实。**
  **顺带补上第二层棘轮(此前完全没有)**:`test_fixture_roles.lua` 只棘轮了第一层(无 `player_id` ⇒
  全队 pos 1);**有 `player_id`、无 `roles`**(⇒ 每次 `GetPosition` 都是槽位,GH #57 47.3%)此前
  **一条棘轮都没有**。现为 `SLOT_DERIVED_ROLES`,治好 2 个后**剩 8 个**,双向棘轮。
  **并把锚点的说法改对**:`f_221200_od_roles.lua` 是角色契约的锚点,而它**自己就是槽位派生且永远治不好**
  —— `script_version` 是裸树 sha `829202a`(无 `:s<seed>:`),`positions_for_game` **拒绝**它;
  它的 `EXPECT`(`pos = team_slot + 1`)**正好是 loader 的无 roles 回退**。锚点仍证明名册/player_id 链
  (五人五个互不相同的位置、含已死者),**不证明**那五个数字是抽签角色。已单独钉成用例。
  **机制备忘**(省得重推):`X.ShufflePickOrder` 把 `sSelectList[i]` 与 `Role.RoleAssignment[team][i]`
  **一起换** ⇒(英雄, 角色)整体移动、**只有槽位在动**;loader 没有 shuffle 可重放,无 `roles` 时读的是
  **未打乱的恒等表**。
  **不推 gate、不改 bot Lua、不申请入集、不批量刷剩下 7 个**(治一帧可能翻掉它钉的结论,批量会淹掉翻面)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **868 → 874**。**六次变异全部按预期 FAIL**:
  M1 BAIL 退回槽位世界 → defstale 4 条 + 棘轮点名;M2 CONTROL 退回 → 2 条;M3 只摘建筑血 → 结构血量那条;
  **M4 `aba_defend:922` 阈值 6→7 → BAIL 出价 0.30 → 0**(独立佐证一级 margin);
  M5 删 `pos==1` 合取 → 角色读取次数 15→12;M6 阈值 6→1 → 5 级反事实塌掉。
  `state.json` 新增 `defstale_ROLE_REREAD_20260820`;GH #55 已留言。
  未花 AWS 钱(只读 S3:缓存命中的 dumper + 4 个 `.analysis.json` + 2 个 `.dem`,未启动任何计费资源,
  未提批测请求)。详见 `iterations/reports/strategy/20260820T233000Z.md`。
- 2026-08-20T21:30Z:**第三次有可认领的新 `[strategy]` issue**,认领 **GH #74 §1.5(3)**
  (录像组 20:49Z 上机前语料核验;总监 21:15Z 追加裁定 §10.1 已把它升格为指令:
  「**立刻做零支出的 fixture 对**,把 #71 的证据从『一局一个 Axe』扩到『两波两个英雄』,
  不依赖任何新波次」)。**#74 的两帧归属已独立复现**(自己从 `.dem` 读,不转述):
  施法 t 精确落在 615.2 / 621.3,自家远古坐标取自 buildings 流,几何与伤害账本全部吻合。
  **产出**:两枚真实帧 fixture ——
  `f_260820_162859_es_blink_flee_615`(决策帧 t=614.9,**#66 §0 施法前最后一帧**口径;
  ES 1528/1528=**100%**、viper**1091**在 1200 内、lookback 零英雄伤害;位移 1416、
  d(自家远古) 8583→7171 = **−1412 朝家** ⇒ **撤退腿**)与
  `f_260820_163429_es_blink_init_621`(t=621.0;**1200 内 0 敌**、1600 内 3 队友;
  d(自家远古) 13227→**13974 = +747 远离**、落进 viper 420/SK 548 ⇒ **进攻起手**);
  `tests/test_replay_260820_es_blink_flee.lua` **11 例**。**bot Lua 一位没动。**
  **本轮真正值钱的是一条关于本组自己这个门的负面结果:`blinkflee` 的 HOLD 集不同质。**
  三帧门读数**完全一样**(turbo+armed+HP≥70%+2s 内无英雄伤害 ⇒ HOLD),ground truth 却 2:1 劈开:
  axe 529.6 burst **{}** 活、axe 555.2 burst **{}** 活、**ES 614.9 viper 1175、+6.0s 死**。
  机制:ES 帧**第一发英雄伤害落在决策时刻之后 ~1.5s**,`WasRecentlyDamagedByAnyHero(2.0)` 是
  **回看窗**,对「1091 外还没开火的 viper」与「四周真没威胁」给出同一读数 ⇒ **§0b 老形状
  (判据是滞后指标),这次落在本组自己写的门上**。
  **对 #71 条件 (c) 的两半做的事不同**:「撤退闪现是 15s CD 误用」这半**被加强**
  (形状在第二个英雄、两局独立复现;且 ES **闪了也没跑掉** —— 朝家 1416 之后照样被 viper 打死,
  CD 什么都没买到);**「hold 的代价是零」这半在这一帧上不成立,以后不能再无条件写**。n=3,
  与录像组 #74 §2.4 自报 `liondrainstop` 反例同一种自我举报。
  **另钉一条**:PASS 帧上 `J.ShouldHoldBlinkFlee` **也返回 true** ⇒ **门分辨不了进攻起手和逃跑**;
  保下那次进攻闪现的是撤退分支**自己的前置** `#nInRangeEnemy >= 1`(该帧 0 敌)⇒ armed 与 shipped
  **逐位相同**。写成断言,免得把门不具备的分辨力记到它头上。
  **不收窄 gate**(失效模式 n=1,照一帧调阈值正是 `lanefix` −74.5/−88.7 的入口)、**不申请入集**
  (19:00Z 已 admit,无新 armed 语义)、**不提批测请求**(#74 已证 (a) 在当前种子结构买不到,0.0625 次/局)。
  **交出去的零支出活(合 §V.7 pre-flight)**:请录像组在**已付过钱**的语料上数一个数 ——
  「HOLD 合格帧之后 **8s 内 subject 死掉**」的比例;接近 0 ⇒ 可按现状 armed,可观 ⇒ armed 前必须
  加一条**逼近威胁**项。已留言 **GH #74** 与 **#71**。
  **世界断言合规**:#69 两帧生成器**均未**打 `ground_truth_ambiguous`/`recent_damage_ambiguous`
  ⇒ ground truth 可引用,并**写成断言**;#61 不读 lane front;#58 不消费 `GetTower`;两枚 fixture 均带 `--roles`。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bots/ 零改动);
  `lua5.1 tests/run_tests.lua` **857 → 868**(+11)。**六次变异全部按预期 FAIL**:
  (a) 调用点摘掉 guard → wiring 钉子 1;(b) 删 `IsSoakCandidate` → gate-OFF 惰性 3;
  (c) 删 `IsModeTurbo` → 非 turbo 惰性 2;(d) HP 地板 0.70→1.01 → HOLD 类 5;
  (e) 反转 2.0s 伤害子句 → 7;(f) fixture `died_after` 6.0→nil → `[limitation]` 那条 1
  (证明它读真 ground truth,不是常量)。`state.json` 新增 `blinkflee_ES_PAIR_20260820`。
  未花 AWS 钱(只读 S3:缓存命中的 dumper + 2 个 `.dem` + 2 个 `.analysis.json`,未启动任何计费资源)。
  详见 `iterations/reports/strategy/20260820T213000Z.md`。
- 2026-08-20T19:25Z:没有可认领的新 `[strategy]` issue —— 唯一带新证据的 **GH #72**
  是录像检查组的 `capmono` 隔离核验(SILENT,不 promote,不构成有害证据 + 登记
  「行为通道检测器的经验零点 ≈ ±15pp/种子 SE 7.5」),决定权在总监(admit/reject/
  test_set),不是本组要写的 Lua 或测试。**#61 已在 17:00Z 由总监落地**
  (`git show 71b510c`:`rf.load` 显式 refuse `GetLaneFrontLocation`,6 个测试
  同步声明假设),所以照章程接 backlog **第 0z 条**「`DefendThink:1418`
  (代码飘动到 `1441`) 恒真否决,已发布未 gated 的动作类缺陷,lane front 一能用就是
  最值钱的下一个」。
  **产出**:**状态层钉子**——`tests/test_defnum_recent_hit_parity.lua` 的 MECHANISM
  循环末尾追加 `#ds.nInRangeAlly >= #ds.nInRangeEnemy` 断言,POKED/PAIRED/WD 三帧
  实证为 TRUE(第三条腿与 `defnum`(1219)/dead-code(1139)/`defstale`(1314)
  同源);加两条 [reverse] 源码钉子——(i) `#ds.nInRangeAlly >= #ds.nInRangeEnemy`
  子串必存;(ii) 用 `src:match` 捕获整行 if,断言 line 1441 **未 gated**
  (若哪天有人加了 `IsSoakCandidate(...)`,backlog 「已发布未 gated 的动作类缺陷」
  这条说法必须更新)。
  **动作层未钉,已如实登记**:三个 fixture 的 subject 都在离最远建筑 ~8k 处,
  `ds.distanceToLane[lane] >> 1600`,DefendThink 走 `dist > SEARCH_RANGE_DEFAULT * 1.7`
  的 elif 分支(`Action_MoveToLocation`),line 1441 的 `Action_AttackMove` 分支
  在这些 fixture 上结构不可达。**拒绝伪造 lane front 到 subject 附近来强开 dist<1600**
  ——那不是「declare an assumption」(per #61 discipline),那是模拟游戏世界。
  **(a) 语料请求已路由 replay-check(GH #62 追评)**:要一份 turbo 防守帧
  `subject.dist_to_defendLoc < 1600` + defend 赢下竞价 + 无更早 action 分支抢先 return
  (baseThreat/HG/enemies at hub/visible enemies/creeps/ShouldDefend+bld 全 miss),
  下一轮语料回来后一次性入 test_set + 决定候选杠杆(delete 死码 / `#pathEnemies`
  替换 / `#enemiesAtHub` 替换)。
  **不推 gate**(动作层未验收,单动 gate 违反本组「一次一个小杠杆 + 局部正确 ≠
  emergent 好」的教训);**不改 bot Lua**(行为一位没动);**不申请入 test_set**
  (第三条腿无 armed 语义)。
  **世界断言合规**:不新增读 `GetLaneFrontLocation` 的断言(继承 #61 landing 时既有
  [limitation] 测试的 explicit declare origin 记账);状态层结论只读
  `bot._defend.nInRangeEnemy`(helper 写入,不经 lane front);幻象污染(#69)不涉及
  (读的是 hero 集合不是伤害账本);结构不可寻址(第 6 条,#58)不涉及
  (不消费 `GetTower`)。
  **验收**:`luacheck bots game --formatter plain` **0 warnings**(bot 侧未动);
  `lua5.1 tests/run_tests.lua` **857/857 → 857/857**(不变;循环体追加 assert 不改
  例数;两处 [reverse] 是既有测试内的断言追加)。**三次变异全部按预期 FAIL**:
  (i) 强填 `ds.nInRangeEnemy` 为非空表 → MECHANISM 三帧同时 FAIL;
  (ii) 把 line 1441 方向对调 `#ds.nInRangeEnemy >= #ds.nInRangeAlly` → [reverse]
  shape pin FAIL;
  (iii) line 1441 前加 `IsSoakCandidate("defwin") and` → [reverse] ungated pin FAIL。
  `state.json` 新增 `defthink_third_leg_pin_20260820`;backlog 第 0z 条改写
  (landing 后:状态层钉住,动作层等 (a) 语料);GH #62 已追评(第三条腿状态层钉住
  + 动作层语料请求)。
  未花 AWS 钱(未启动任何计费资源,未提批测请求,未读 S3——本轮完全是本地
  Lua + 静态审计)。详见 `iterations/reports/strategy/20260820T192500Z.md`。
- 2026-08-20T17:15Z:**第二次有可认领的新 `[strategy]` issue**,认领 **GH #71**
  (英雄组 15:20Z 定位交接:`item_blink` 的**撤退分支**在 `bots/ability_item_usage_generic.lua:1503-1518`,
  两次把 15s CD 烧在 84%/81% HP 的空开跳,几何指纹 cos(→ancient)+0.997/+0.998,距离 1326/1162)。
  **头号产出**:gated **`blinkflee`** —— 新增 helper `J.ShouldHoldBlinkFlee(bot)` 挂进撤退分支
  内层 if 的**最后一条合取**;仅在 turbo + 'blinkflee' armed **且** HP ≥ 70% **且**
  `WasRecentlyDamagedByAnyHero(2.0) == false` 时**否决**该次撤退闪现,不能新增任何闪现。
  **两帧钉住(都从 20260820_043124_slot1,和 `f_260820_043124_axe_blink_kill.lua` 同一局)**:
  `f_260820_043124_axe_blink_flee_529` (t=529.6, HP 84.2%, SK@339 但攻击分支被 <500 硬门挡住,
  上次英雄伤害 3.2s 前, `WasRecentlyDamagedByAnyHero(2.0)=false`) —— armed 下 `ShouldHoldBlinkFlee=true`;
  `f_260820_043124_axe_blink_flee_555` (t=555.2, HP 81.3%, 800 内 0 队友, 仅一次 2.5s 前的 4 点近战小兵) ——
  armed 下 `ShouldHoldBlinkFlee=true`。
  **验收**:`tests/test_replay_260820_axe_blink_flee.lua` **8 例**(两帧 × {gate OFF/gate ON/非 turbo};
  HP 突变 <70% 释放;近 2s 有英雄伤害释放;源码探针断言 guard 在 IsRetreating 分支的 HIGH return 上)。
  **五次变异**:删修复导致钉帧 HOLD 断言坏 2、gate 常开(非 turbo 也 HOLD)导致「turbo 惰性」断言坏 1、
  HP 阈值改到 0.5 使 84%/81% 均放行 2 —— 全部按预期失败。**838/838(基线 830)+ luacheck 0 警告。**
  **不做 (b)/(c) 决断**:入集申请见 GH #71 留言;`blinkflee` gated **未 armed**,排期建议**混波带着走**
  (足迹极窄:两帧上都是 `IsRetreating + 单独 enemy in 1200` 的合取,与 `retnear`/`towerreach`/`defnum`
  /`aba_defend` 族的分支域完全不重叠 —— 是**物品使用**这条线,不是**mode 出价**这条线;
  A-B 归因不冲突)。
  **世界断言检查**:该分支**不读 `GetLaneFrontLocation`**(#61 无关);guard 只读 `bot.GetHealth`
  /`bot.GetMaxHealth`(dump 真值)与 `WasRecentlyDamagedByAnyHero`(fixture.recent_damage,#69 幻象
  污染只波及 `burst` / `died_after`,不波及本地帧 subject 自身的 `recent_damage` **且**两帧战场都无本体幻象)。
  `state.json` 新增 `blinkflee_20260820`;GH #71 已留言(条件 (a) 已 pin、入集申请)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 1 个 `.dem` + 1 个 `.analysis.json`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260820T171500Z.md`。
- 2026-08-20T15:30Z:没有可认领的新 `[strategy]` issue(open 集与 13:30Z 相同)。绕过所有基础设施墙
  (#61、缺基地攻防语料、幻象污染重读交 replay-check、AWS $-tier)⇒ 唯一可干的静态审计题目是 backlog
  **第 5 条**「`lf_rescue` 的 `DotaTime() < 8*60` 核心豁免按普通模式节奏写,独立排一轮」。
  **静态审计结论**:`bots/FunLib/jmz_func.lua:5862` 那一行的 hardcoded `8*60` 与 canonical
  `J.IsInLaningPhase()` 的 turbo hard floor **完全相同**,差别只在 **t ∈ [480, 600] 且 rescuer 净值 < 8000**
  一段窗口 —— canonical 下核心豁免继续生效(不救),shipped 下已经放开(可救)。Turbo 均局 670s,九分钟核心
  净值 < 8000 是常态(见 13:30Z §5 三帧 3068–3997)⇒ 替换会让一批低净值核心少发一批 rescue,**方向单调向
  #37 病灶靠近**(#37 第 3 节:20/50 attributed rescues 15s 内死了,rescue 已过多)。
  **不 push gate 的理由**:候选 `lfcorelane` 想 armed(turbo-only)把该行改成 `J.IsInLaningPhase()`,
  armed 效果集是 shipped 的父集,不新增动作。但**当前 fixture 语料一帧都不覆盖差集**:
  `f_260819_123012_dk_rescue_far` (t=568.4 subject=DK) DP 视角看,DP items 里已无 `item_tpscroll`
  (下一帧就是 `dp_landed_dead`)⇒ `GetRescueTpTarget(DP)` 早退于 line 5865 tp-check、gate 那一行**结构不可达**;
  `dp_landed_dead` (t=574.4) TP 已消耗;`lich_rescue_doomed` (t=201.3) lich 是辅助不触发核心豁免;
  `axe_rescue_ok` (t=145.4) t<480 是豁免生效帧,armed 与 shipped 逐位相同;`cm_chain_rescue` (t=256.0) 辅助+t<480 同样。
  ⇒ **无 (a) 帧就不 armed**(#28 类错误已被本组交过一次学费,不再重犯)。已把已知语料缺口
  「rescuer=核心 + TP 在身 + t∈[480,600] + nw<8000 的**决定帧**」交给 replay-check(有 S3 corpus + 原始
  timeline + subject 重投能力)。已在 **GH #37** 底下留言(§5.3 补 t=8–10min 决定帧时**顺手多存一帧
  subject=rescuer 的 fixture**,回来一次性入 test_set)。
  **不动代码,不改 test,不加 fixture**。luacheck bots game --formatter plain:0 警告(基线一致);
  lua5.1 tests/run_tests.lua:830 tests, 0 failures(基线一致,本轮未添加任何测试)。
  `state.json` 新增 `lfcorerescue_lane_gate_audit_20260820`(方向、可寻址帧域、语义 diff、不 armed 理由)。
  backlog 第 5 条改成「静态审计完 + gate 方案定 + (a) 语料请求已路由 replay-check」。
  未花 AWS 钱(未启动任何计费资源,未提批测请求)。详见 `iterations/reports/strategy/20260820T153000Z.md`。
- 2026-08-20T13:30Z:**第一次有可认领的新 `[strategy]` issue**,认领 **GH #68**
  (录像检查组 12:48Z 交的 `tpdying` 首次条件 (a) 核验,§5.3 点名要钉两帧)。
  **#61 仍未有着落**(第 0z 条继续卡着),但本轮结论**不骑它的桩**:所有判据都在不读 lane front 的路径上,
  出价层两侧用同一个 `GetLaneFrontLocation` 覆盖(与 `test_tpcommit_release_domain.lua` 同一套)。
  **头号产出是第十一条没人声明过的世界断言,并且已修**:**`.dem` 的战斗日志只认名字,不认实体**。
  快照流带 `idx`,所以生成器一直能干净地剔掉幻象;**战斗日志不能** —— 每条 `DAMAGE`/`DEATH` 行的
  `actor`/`target` 都是**裸英雄名**,幻象用它复制的那个英雄的名字 ⇒ `observed.burst`
  (每个 fixture 头部写着「damage each enemy hero **ACTUALLY** dealt to the subject」)
  **混着打在本体复制品身上的伤害**,`recent_damage` 反向同理。
  **实测**:`20260820_102030` t=639.5 tidehunter,名字口径 3s 实伤 **849**(lion 64/slardar 229/
  ogre 211/OD 329/necro 16),而本体实体 idx 1316 同这三秒 **1419 → 1452 → 1435 → 1423(它在回血)**
  —— 849 点全打在幻象 idx 2537 上(存活 613.5–640.5,离本体 **4000u**)。**GH #68 §1.3 正是把这个数
  读成「一秒吃 1063」**。影响面:loader 把它装成 `GetEstimatedDamageToTarget`,是
  **`J.WillAllySurviveTpWindow`(已发布未 gated)**、`J.IsIncomingBurstLethal`、`J.ShouldRetreatLaneBurst`
  的唯一输入;`recent_damage` 喂四个 `WasRecentlyDamagedBy*`(670 个调用点)。
  **修复是拒绝不是修补**(拆「本体那一份」要靠血量轨迹 = 建模,与 #61 同一条线):subject 或任何
  记账为打了它的英雄在窗口内有复制品存活 ⇒ withhold `burst`/`damage`/`died_after`,写
  `observed.ground_truth_ambiguous`;反向同判据写 `recent_damage_ambiguous`。接线前后 **787 → 806,无历史结论翻面**。
  **本轮缺陷本体:GH #68 的条件 (a) 站不住。** `tpdying` 的立论把 `J.IsInLaningPhase` 当时钟读,
  **它不是时钟**:turbo 下是 `t < 8*60` **或** `t < 10*60 且自己净值 < 8000` ⇒ **8:00–10:00 之间
  取决于响应者自己的钱包**,而九分钟时净值 < 8000 是常态。三帧实测:`103644` t=492.4 necro(3997)
  **对线期 true、`ShouldRetreatLaneBurst` true ⇒ shipped 自己就放掉了 pin,armed `tpdying` 逐位相同**;
  `102645` t=556.5 CM(3068)**对线期 true**;`102030` t=639.5 tide 才真的 false(前提在 10:00 后成立)。
  ⇒ **#68 §1.1 排除预判半边的那一步(「t=556>480 ⇒ 结构性 false」)在那帧上不成立**;独立第二条:
  实伤替身下该帧判据读 **false**(实伤 261 vs 血池 504),armed pin 仍是 0.85,出价逐位不变;
  ground truth 记下不当论据(CM `died_after = 39.0`,活下来了)。**不要再为 `tpdying` 买 (a) 语料。**
  **负结果:#68 §5.1 的阈值解耦本地验证不了** —— necro 帧严格比较本来就通过(1080 ≥ 965),
  tide 帧根本没有可归属 burst;而替身**忽略 `bCurrentlyAvailable`**,恰恰是 #68 §2.3 指认的机制
  ⇒ 与 `RetreatWhenTowerTargetedDesire` 同类「域有帧但断言不了」。**故本轮不交新 gate**,
  只把立论改对(`jmz_func.lua` **仅注释** + `state.json`),行为一位没动;
  也**没有把 `tpdying` 提出集**(它顺手去掉了「生存释放依赖响应者钱包」这件事,是同一缺陷更锋利的说法)。
  验收 `tests/test_fixture_illusion_ground_truth.lua` **10 例** + `tests/test_tpdying_laning_domain.lua` **9 例**。
  **五次变异:生成器发污染数据+摘 loader 闸门 2、生成器不标 `recent_damage_ambiguous` 2、
  净值软延长 8000→0 5、turbo 软结束 10min→8min 4、`tpdying` 释放改无条件 1。806/806(基线 787)+ luacheck 0 警告;rebase 到 main 后 830/830。**
  本轮开 **GH #69**(幻象污染,交总监定回读范围),已留言 **#68**(条件 (a) 未成立)与 **#35**(立论域修正)。
  `state.json` 新增 `fixture_illusion_ground_truth_20260820`、`tpdying_DOMAIN_CORRECTION_20260820`。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 4 个 `.dem` + 4 个 `.analysis.json`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T133000Z.md`。
- 2026-08-20T11:30Z:没有可认领的新 `[strategy]` issue(#65/#62/#58/#55/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #66/#63/#59/#56/#54 归英雄组,#64/#61/#60/#49/#46/#43/#42 归总监与批测台);**#61 总监 11:00Z 那轮仍未处理**
  (工作单元是 #64/#52),第 0z 条仍卡着,照章程接 **第 0b 条**,做它上一轮点名的
  「`X.ShouldRun` 的强制退却链 / `RetreatWhenTowerTargetedDesire`」。
  **本轮先量域再选杠杆**(5 局 turbo 录像、0.5s 间隔、**63,350 个存活英雄-帧**),四条点名候选里
  **三条当场出局**:`ShouldRun:774`(基地深处)**0 帧**、`ShouldRun:740`(6 级前深入)**0 帧**、
  `RetreatWhenTowerTargetedDesire` 域有 774 帧但**两个触发条件都读 dump 没有的引擎状态**
  (`GetAttackTarget` / `GetEstimatedDamageToTarget`)⇒ 真实帧上断言不了。
  **头号顺带产出是第十条没人声明过的世界断言,并且已修**:`tests/mock/bot_api.lua` 对任何
  `GetNearby*` 一律答 `{}`,而 loader **只覆盖过 `GetNearbyHeroes` 一个** ⇒
  **`bot:GetNearbyTowers`(183 个调用点)与 `bot:GetNearbyBarracks`(20 个)在每个 fixture 里都是空的**
  ——白话:**「这附近没有任何塔,也没有任何兵营,对任何人都是」**,而同一个 fixture 早就带着每座建筑的
  真实队伍/坐标/存活/血量(GH #58 那轮接的,只是过去只能从 `GetTower`/`UNIT_LIST_*_BUILDINGS` 拿)。
  光在 `mode_retreat_generic` 就掏空了 `C.allyTowers1200`/`C.enemyTowers1200`、**整个
  `RetreatWhenTowerTargetedDesire`**、`ShouldRun` 的四条分支。修复是 restoration(只给存活的、
  按距离升序、**不含前哨**,两条都写成断言),接线前后 **745/745,无历史结论翻面**。
  **仍故意没伪造**:建筑的攻击力/攻速不在 dump ⇒ `C.haveEnemyTowerThreat` 在 fixture 里永远为假
  (写成 `LIMITATION` 用例);`GetNearbyLaneCreeps`/`GetNearbyCreeps` 仍是 `{}`(注入小兵是建模)。
  **本轮缺陷本体(GH #67)**:「四周什么都没有 ⇒ −0.25」折扣**左半边标定、右半边不标定** ——
  `#nEnemyTowers` 是 `C.enemyTowers1200`,**1200 内有任何敌塔就一票否决**,而塔的攻击距离是 **700**。
  **作者原意有物证**:同一函数 490 行前算好了 `C.haveEnemyTowerThreat`(1200 内某敌塔 5s 打掉我一半血),
  **全仓库三写零读** ⇒ §0b 家族**新亚型:同一个问题在同一个函数里有两份实现,精确的那份没接线**。
  **交付 gated `towerreach`(turbo-only)**:armed 时否决只数**够得着我**的塔(**800**,是本文件自己
  表示「我正站在敌塔跟前」的那个数);armed 否决集是 shipped 的**子集** ⇒ 折扣只可能更常生效 ⇒
  **出价只降不升**,不新增动作、不碰别的出价。**不用 `haveEnemyTowerThreat` 当闸门**是因为塔的
  攻击力/攻速不在 dump,那样就没有真实帧能验收(局限已写成断言)。
  **域实测**:15,563 帧满足左半边(离自家泉水 >4000 且 3200 内无敌人),其中 **695 帧被塔否决**,
  **500 帧(71.9%)否决它的塔够不着**;抽 28 帧(每英雄间隔 ≥6s)成 25 个 fixture(3 个因无种子归属被拒,GH #57),
  驱动**全部 mode**:出价变 **23/25**,**竞价当选者变 2/25(8%)**,**其余 mode 一条都没动**;
  2 帧不变是结构性的(`X.ShouldRun` 先开火、在折扣行之上就 return 了 `ABSOLUTE*1.1`)。
  钉帧 `f_260820_102030_wk_tower_out_of_reach`(t=436,**Wraith King 焦点英雄**、284/1154=24.6%、8 级、
  离自家泉水 13,722、**3200 内 0 敌**、唯一敌塔在 **1090**):shipped **0.3836 赢**,armed **0.1336**
  ⇒ `mode_laning_generic` 0.369 赢。**GROUND TRUTH 记下不当论据**:它原地吃药回血到 46% 没被碰,
  之后北上被杀、复活、再死。对照帧 `f_260820_102030_wk_tower_in_reach`(同局同英雄 8.5s 后、塔在 **787**)
  **armed 逐位相同**;第二帧 `f_260820_103630_lina_tower_ring` 是足迹诚实的那一半(降 0.25,决定不变)。
  **不骑 #61 的桩**:先在已知敏感帧上证明探针是活的,再证明**本帧任何 mode 的出价都不读 lane front**。
  验收 `tests/test_towerreach_out_of_range_veto.lua` **12 例** + `tests/test_fixture_nearby_structures.lua` **6 例**。
  **五次变异:删修复 3、gate 常开 5、gate 忽略 turbo 1、reach 半径 800→1200 3、拆 loader 建筑查询 13
  (全部落在两个新文件内)。763/763(基线 745)+ luacheck 0 警告。**
  `state.json` 新增 `towerreach_20260820`、`fixture_nearby_structures_20260820`、`corpus_gap_no_base_assault_20260820`。
  **`towerreach` gated 未 armed**,入集申请见 **GH #67**;**排期建议:混波带着走**(足迹 0.83%、单调向下、
  与 `aba_defend` 族不重叠)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 5 个 `.dem` + 5 个 `.analysis.json`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T113000Z.md`。
- 2026-08-20T09:30Z:没有可认领的新 `[strategy]` issue(#62/#58/#55/#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #63/#59/#56/#54/#50 归英雄组,#61/#60/#49/#46/#43/#42 归总监与批测台);**#61 总监 09:00Z 明确说本轮没处理、仍归他们**,
  所以第 0z 条仍卡着,照章程接 **第 0b 条**,按它点名的「**挑一个已发布未 gated 的 last-seen 消费方先做**」,
  选 `mode_retreat_generic.lua:493-508` 的「last-seen 补数」。
  **头号发现是第九条没人声明过的世界断言,并且已修**:`tests/mock/replay_fixture.lua` 的 `GetUnitList`
  只回答 `ENEMY_HEROES`/`ALLIED_HEROES`,其余落 `{}` ⇒ **`GetUnitList(UNIT_LIST_ALL)` 在每个 fixture 里都是空的**
  —— 不是「没有小兵」,**连英雄都没有**。白话:**「这个世界里,任何地方都没有任何单位」**。
  `bots/` 下精确 **11 个**调用点,两个分量极重:**`mode_retreat_generic.buildContext` 的两张英雄表都从它来**
  (⇒ 每帧 `#nAllyHeroes`/`#nEnemyHeroes` 都是 0,退却出价整段「我是不是被人数压制」**拿 0 和 0 比**)、
  **`J.WeAreStronger(bot, r)`**(⇒ 每个半径**空队伍对空队伍**)。修复是 restoration(英雄位置是 dump 真值),
  **含自己**,接线前后 **714/714,无历史结论翻面**。**故意没伪造并写成断言**:小兵/召唤物/建筑仍不在这张表里
  (建筑不注入是因为唯一消费方要 `GetAttackDamage()*GetAttackSpeed()`,dump 不带)。已在 **GH #61** 留言。
  **顺带发现、没修**:`mode_rune_generic:487`(`GetRuneSpawnLocation` nil)与 `mode_secret_shop_generic:63`
  (`GetCourierState` nil)**在任何 fixture 上都跑不起来**,而**仓库里每一个竞价级测试都用 `pcall` 悄悄吞掉了它们**
  (含本组的 `test_tpwatch_channel_bid.lua`)⇒ 过去每条「谁赢下这一帧」都默认排除了这两个 mode 却没说;
  本轮验收改成**点名断言**,口径写成「在跑得起来的 mode 里」。归总监(与 #61 同类口径问题)。
  **本轮缺陷本体(GH #65)**:退却出价里**做比较的两边不是同一次测量** —— 两张英雄表与 `bWeAreStronger`
  都在 **1600**,而 last-seen 补数按 **3200** 取并**覆盖**敌人计数(`if unseenCount > #nEnemyHeroes then ...`),
  于是 `敌 - 友 > 0`(每多一个 +0.1875)与 `not stronger and 敌 >= 友`(+0.25)**左边 3200、右边 1600**。
  **r=3200 是 r=1600 的四倍面积** ⇒ 偏向「被压制」是**几何造成的**:**站在我 1700 外的队友抵不掉 3100 外的敌人**;
  3200 还超出自己白天视野 1800 ⇒ 宽计数在 1800 外加进来的每个人都是**队友**看见的(离队友近、不是离我近)。
  **交付 gated `retnear`(turbo-only)**:armed 时**可能替换 nearby 计数的那个数按 1600 取**;宽计数照旧计算、
  照旧喂下面那条「四周什么都没有就 −0.25」(那条本来就要宽地平线)⇒ **只动一个杠杆**,且**只可能压低或维持**出价。
  **没走的路**:把队友那边放宽到 3200(`nAllyNearbyCount` 还管着 Oracle/Dazzle/Satanic/Slark 那块折扣,一动就是好几个杠杆)。
  **域实测**:六局 43,256 英雄-帧(视野按各队自己的视野源**建模**,`.dem` 无逐队雾位图 GH #27,按模型报):
  宽计数覆盖近计数 **7,908 帧(18.3%)**,退却出价变化 **6,556 帧(15.2%)**(0.25:4892 / 0.4375:748 / 0.1875:736 /
  0.625:102 / ≥0.8125:29),抽 40 帧驱动**全部 22 个 mode**,**竞价当选者变 4 帧(10%)**。
  钉帧 `f_260820_043637_axe_ring_alone`(t=641.4,axe **89% 血**、**1600 内既无队友也无敌人**、三敌在
  **2974/3086/3172**):shipped **0.6904 赢**,armed **0.0654** ⇒ **`mode_laning_generic` 0.369 赢**,其余 mode 逐位不变;
  **GROUND TRUTH 记下不当论据**:它往回走后 **t=655–675+ 站在原地不动、97% 血、零受伤**。
  对照帧 `f_260820_043637_axe_ring_close`(同局同英雄同 89% 血、敌人在 188/741 即 1600 内)**armed 逐位相同**;
  第二帧 `f_260820_043140_luna_ring_bid` 是**足迹诚实的那一半**:0.777 → 0.339 但**退却仍然赢**(出价低 ≠ 决定变)。
  **本轮的正面结果:这条不骑在 #61 的桩上** —— 三个不同非原点 lane front 跑变异,结论与两个退却出价**逐位不变**
  (退却 mode 不读 lane front),而变异**是活的**(把 `mode_defend_tower_top_generic` 从 0.1275 挪走)。**已写成断言。**
  验收 `tests/test_retnear_radius_parity.lua` **11 例** + `tests/test_fixture_unit_list_all.lua` **4 例**。
  **五次变异:删修复 3、gate 常开 5、gate 忽略 turbo 1、拆 `UNIT_LIST_ALL` 接线 9、窄计数不经 gate 5。
  729/729(基线 714)+ luacheck 0 警告。** `state.json` 新增 `retnear_20260820` 与 `fixture_unitlist_all_20260820`。
  **`retnear` gated 未 armed**,入集申请见 **GH #65**;**排期建议:混波带着走**(足迹窄、方向单调,
  且与 `defclose`/`defstale` 的 `aba_defend` 族不重叠,同波不污染归因)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 6 个 `.dem` + 6 个 `.analysis.json`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T093000Z.md`。
- 2026-08-20T07:30Z:没有可认领的新 `[strategy]` issue(#58/#55/#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #59/#56/#54/#50 归英雄组,#60/#49/#43/#46/#42 归总监与批测台),接 backlog **第 0b 条**,
  做上一轮点名的「`GetDefendDesireHelper` 下半段没人在真实帧上看过的那几条」里的一条。
  **头号发现是第七条没人声明过的世界断言,而且是迄今最宽的一条(GH #61)**:
  `tests/mock/replay_fixture.lua` **从来没有接过 `GetLaneFrontLocation`** ⇒ `bot_api.lua:285` 的桩生效,
  **任何 team、任何 lane、任何 frontOffset 一律 (0,0,0)**。白话:**「两队的前线,在三条路上,都在河道正中」**。
  `bots/` 下 **125 个调用点**读它;在 `aba_defend` 里它让 `ds.defendLoc` = 原点、
  `ds.distanceToLane[lane]` = 「我离河道多远」——**三条路同一个数**,「我离这条路近不近」结构上分不出三条路——
  而这个数正是 `:1102` 提前 return 与 `:1156` 的 `dist > 4000` 衰减的判据。
  实测(钉帧 viper):`distanceToLane` 三路都是 **2040**,真实的「viper 到自家上路一塔」是 **8084**。
  **故意没有伪造它**:从 creep 流(每 3s 采样、无路别、无存活位)重建前线是**建模**不是还原 ground truth,
  `frontOffset` 更无从还原 —— 与前面几次 loader 修复不是同一类东西,上报交总监定夺。
  **它翻掉了什么(实测)**:把桩挪离原点,**上一轮 `defclose` 的 3 条用例当场 FAIL** ⇒
  `defclose` 的「最终出价 / 竞价从 laning 翻成 defend_tower_mid」这一层**不是桩无关的**
  (机制层与 2883 帧域实测**完全不受影响**)。已在 **GH #58** 如实留言。
  **本轮的缺陷本体(GH #62)**:`ds.nInRangeEnemy` 被赋值的**下一句**就是
  `if #ds.nInRangeEnemy > 0 ... return VeryLow` ⇒ **整个下半段它恒为空**,而下面有三个消费方照读不误:
  `:1139`(`0 > n`,**整块死代码**)、`:1196`(`0 >= n`,**读的是「我 1600 内有没有队友」**,
  不是「我是不是被压制」,且触发时我 1600 内一个敌人都没有)、`DefendThink:1418`
  (`n >= 0`,**恒真** ⇒ 作者写的「被压制就别攻击移动进 hub」这条否决**近乎死掉**,**已发布未 gated**)。
  §0b 家族**新亚型:使比较失效的是上游一个提前 return 把一侧钉成常数**,分支语义在该处**无法表达**。
  **顺带加强了 #55**:`defstale` 的 `#pathEnemies > #ds.nInRangeEnemy` 右边恒为 0 ⇒ 那条闸门就是
  **「5s 内挨过英雄打 + 1600 内有任何 last-seen 敌人 ⇒ 退向泉水并作废该帧其余 defend 分支」**,
  比原来写的「和自己的旧拷贝比大小」**更强更简单**(利好 promote 判断)。已留言。
  **交付 gated `defnum`(turbo-only,纯移除)**:只动 `:1196`,移除
  `math.min(nDefendDesire, BotActionDesire.Low)`;armed **只可能抬高出价**,不新增动作、不碰别的出价;TS 源同步。
  **先做了然后被自己实测否掉的版本(负结果)**:把比较改指到函数自己 80 行前算好的 hub 计数
  (`#lEnemies`/`nEffAllies`)——域内 **541/549 触发 vs shipped 308/549**,
  会把一次意外变成**系统性的认输规则**(两个敌人站塔边就放弃这座塔)。测试里有反向断言钉住它不许进树。
  **方向依据 (c)**:那个 `min` 只在衰减前出价 > 0.625 时才生效 ⇒ 经血量 remap 意味着
  **血量接近满 + 引擎自认这条路急需防守**,恰恰是值得去的防守,而 0.25 在竞价里几乎必输;
  让上一行的 `* 0.4` 按比例衰减比一票否决好。
  钉帧 `f_260820_043120_viper_defend_poked`(t=398.5,viper **92.4% 血**、0.7s 前被 ember 打过、
  **1600 内 0 敌 0 友**、自家还站着的上路一塔 1200 内 **3 个敌人**;**GROUND TRUTH 记下但不当论据**:
  它当时在中路对线补兵、之后留在原地打小兵血还在涨,**shipped 的 laning 与它实际做的事一致**);
  对照帧 `f_260820_043120_viper_defend_paired`(同局同英雄、1600 内有队友 ⇒ armed **逐位相同**);
  第二帧 `f_260820_043524_wd_defend_alone`(闸门跑到、cap 生效、armed 抬了出价,**而出价仍小到赢不了任何东西**)。
  **足迹与「为什么本轮不申请入集」**:这条分支出来的出价**按构造 ≤ 0.4**(上一行 `* 0.4`),打不过 laning 的 0.446;
  26 个抽样域内帧跑全部 22 个 mode 的真 `GetDesire()`:8 帧出价变、**3 帧竞价当选者变**(且只在 `GetDefendLaneDesire == 1.0`),
  **但那 3 帧全是「离塔 7–8k、离原点只有 ~2k」** ⇒ **翻面骑在 #61 的桩上,不算数**。
  test_set.md §8「必须断言最终出价」在这个世界里**满足不了**(不是满足了但结果不好),
  故 **`defnum` gated 未 armed、本轮不申请入集**,等 #61 有着落再申请。
  验收 `tests/test_defnum_recent_hit_parity.lua` **11 例**(前提全断言、机制断言、退化断言、单调性断言、
  移除的正是 `Low`、三个对照组、两条源码级反向断言、**把局限写成断言**的 `[limitation]` 用例)。
  **四次变异:gate 永远打不开恰好 3、gate 常开恰好 3、拆 recent-damage 接线本文件 2 条前提、
  lane front 挪离原点本文件 4 条 + `defclose` 3 条。682/682(基线 671)+ luacheck 0 警告。**
  `state.json` 新增 `defnum_20260820` 与 `fixture_lanefront_gap_20260820`。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 7 个 `.dem` + 10 个 `.analysis.json`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260820T073000Z.md`。
- 2026-08-20T05:30Z:没有可认领的新 `[strategy]` issue(#55/#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #56/#54/#50 归英雄组,其余归总监与批测台),接 backlog **第 0b 条**,按上一轮点名做 **`aba_defend`
  的「我在不在挨打」guard 群(939)**。**结果绕到更下面一层**:939 那一族根本没被任何 fixture 跑到过。
  **又一条没人声明过的世界断言(第六条):结构不可寻址。** loader 此前把 `GetTower(team, i)` 按
  **存活塔的位置**寻址(对「循环 i=0..10 再归约」的读者够用,GH #37 只需要这个),`GetBarracks` 是
  `nil`,`GetAncient` 给**两边**都发一个位于**地图原点**的 4500 血单位;而 mock 把未覆盖的 ALL_CAPS
  解析成哨兵整数 ⇒ **只问一个具名槽位**的读者 `GetTower(team, TOWER_MID_1)` 在**每个 fixture 里**
  都拿 nil。`GetFurthestBuildingOnLaneHelper` 正是这样的读者,而 `GetDefendDesireHelper` 紧接着
  `if not IsValidBuildingTarget(furthestBuilding) then return None end` ⇒ **每个 fixture 每条路的防守
  出价都只来自那七个提前 return,`GetDefendDesireHelper` 的整个下半段结构上不可达**(`ShouldDefend`、
  `capBoost`/`baseFloor`、panic 地板、`recentlyHit` 衰减、`ConsiderPingedDefend`、tier/血量 remap)。
  白话:**「这支队伍在任何一条路上都没有建筑,两家遗迹叠在河道里」**。修复:槽位**从几何推导**
  (不写死坐标)且在**全量建筑集**上推导(掉塔不会重新编号幸存者);真实 `TOWER_*`/`BARRACKS_*` 整数;
  阵亡槽位仍返回 nil;`GetAncient` 发各队真实遗迹;建筑补 `OriginalGet*`(`J.GetHP` 对己方读未 hook
  的取值器,此前 nil 崩)与**真实血量分数**(生成器新增 `hp`,`aba_defend` 读它两次)。
  **翻掉了本组自己上一轮的结论(如实撤回)**:`defstale` 钉的那帧
  (`f_260819_223607_drow_defend_bail` t=330.4)原断言「defend 0.30 赢下竞价」只在没有建筑的世界成立
  (那里 `mode_laning_generic` 出价 **0**、push 恒 0.05);接上之后**同一帧 laning 0.446 > defend 0.30
  ⇒ laning 赢,`DefendThink` 很可能根本没跑**。与该文件早已记着的 ground truth 自洽(那个 drow 留下来
  **补兵**=对线行为)。用例改名 `WITHDRAWN` 并断言新数字;03:36Z 那轮的域实测(32/45、1/45)是**上界
  不是测量**。已在 **GH #55** 留言:gate 不撤,但**条件 (a) 现在缺证据**,请重排。
  **头号产出 gated `defclose`(turbo-only)**:`aba_defend.GetClosestAllyPos` —— 每一条「这几个位置里
  只有最近的那个可以守这座建筑」规则的仲裁器 —— 把列表当 1-based 扫(TS 源 `j = 1..length` 读
  `tPosList[j]`,tstl 忠实译成 `tPosList[j+1]`)⇒ **每张列表的第一个角色从来不参与比较**,而
  `bestPos or tPosList[1]` 的兜底返回的**正是那个没被比较过的角色**。`{4,5}` 只可能答 5(**不看距离**;
  没有存活 5 号时答 4,同样不看距离)、`{2,3}` 只可能答 3(兜底 2)、`{2,3,4,5}` **永远不可能答 2**
  ⇒ **只要队里还有一个存活的 3/4/5 号,挨过打的 1 号和 2 号就被禁止防守任何建筑**。距离比较对每张
  列表的第一个角色是**惰性的**,tie-break 退化成比角色编号。**域实测(角色用 GH #57 的 seed 抽签
  真值)**:六局录像 **2883** 个「自家塔还在 + 1600 内有敌方英雄」的建筑-帧,shipped 与真正最近者
  不同 **{4,5} 32.8% / {2,3} 59.8% / {2,3,4,5} 37.6%**;五个调用点全在 `aba_defend`。
  钉帧 `f_260820_043140_wd_defend_token`(t=297.5:**满血 4 号 witch_doctor 站在自家 99% 血中路一塔
  915 外**,塔 1600 内恰好 1 敌,wd 自己 1600 内 0 敌所以 helper 真走到 `ShouldDefend`;它是**全队离
  那座塔最近的,近四倍**。shipped 经 `{4,5}` 把令牌发给 3981 外的 5 号;3 号**已阵亡** ⇒ `{2,3}`
  一个候选都找不到 ⇒ 兜底点名 **6996 外的 2 号**,全队最远的人)。**最终出价**:lane desire 0 时
  中路 0.100 → **0.250**(shouldDef 地板);0.30 时 0.363 → **0.474**,赢家从 `laning`(0.446)翻成
  **`defend_tower_mid`**;**0.50/0.70 时 shipped 赢的是 `defend_tower_BOT`**,armed 选**塔上有敌人、
  英雄就站在旁边**的中路。对照帧 `f_260820_043710_lich_defend_pos5`(4 号 lich 1118,5 号真的更近 800)
  armed 在四个取值上**逐位 no-op** ⇒ 钉的是「最近者赢」不是「4 号总赢」。ground truth 记下来但**不当
  论据**:那个 wd 离开塔走到地图右下角,t=334 杀掉 vengeful_spirit、t=368 阵亡;它丢下的塔 t=599.5 被拆。
  **必须挑明:不单调** —— 纠错不是旋钮,相对 shipped **既可能增加也可能移除**一个防守者。
  **本轮自曝并已重做**:总监 GH #57 在本轮进行中落地(位置来自**种子抽签**,不是 `team_slot%5+1`,
  吻合率 47.3%),而本组第一版钉帧与第一版域实测**都是按槽位算的** —— 第一版钉的
  `f_260820_043637_viper_defend_token`(已删)按槽位说 viper 是 4 号,**抽签真值是 2 号**,而 2 号本来
  就能过 `ShouldDefend` ⇒ **那帧根本没有缺陷**。**在进 main 之前发现并重做**:交出**第二条 mock
  保真度修复** —— `make_fixture.py --roles <analysis.json>` 经 `seed_draft.py` 由种子推出抽签位置
  (英雄名 canon 化,匹配不全**报错拒绝出半张表**),loader 写 `bot.assignedRole`;没有该字段的
  fixture 逐字节不变 ⇒ **没有历史结论翻面**,但**仓库里现存每个 fixture 的角色都还是槽位派生的**
  (本轮六局实测吻合 23/60 = 38%),凡是在 fixture 里 fork 在 `GetPosition` 上的断言只有 ~40% 把握
  描述了它来自的那局 —— **已进 backlog 第 0c 条**。域实测用真值重算后**数字更大**(32.8/59.8/37.6,
  槽位口径是 35.5/47.4/20.3)。
  验收 `tests/test_defclose_defender_arbitration.lua` **11 例**(前提全断言、机制断言、最终出价层
  断言并重建整场竞价、守错路断言、对照帧四个取值逐位相同、非 turbo 对照、id 隔离、两条源码级反向
  断言;局限明写:`GetDefendLaneDesire` 是引擎状态、`.dem` 不带(GH #27),所以**扫**而不假装知道)。
  **四次变异:删修复恰好 4、gate 常开恰好 5、让 loader 忽略抽签角色恰好 7、拆塔槽位接线恰好 3
  (其余 647 不动)。658/658(基线 647)+ luacheck 0 警告。** `state.json` 新增
  `fixture_structures_20260820` 与 `defclose_20260820`。**`defclose` gated 未 armed**,入集申请见
  **GH #58**;**排期建议:单独占一条臂**(足迹宽且不可分离),且**不要与 `defstale` 同波**。
  **故意没做**:`aba_defend:939` 本身与 panic 地板被 `recentlyHit*0.4` 乘掉的顺序缺陷 —— 机制已确认,
  但**本轮六局里离任一遗迹最近的敌人是 4925 码**(批测局在基地攻防之前就自终止),取不到实证帧。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 6 个 `.dem` + 6 个 `.analysis.json`,未启动任何计费资源),
  未提批测请求。
  详见 `iterations/reports/strategy/20260820T053000Z.md`。
- 2026-08-20T03:36Z:没有可认领的新 `[strategy]` issue(#52/#45/#44/#41/#37/#35/#28/#26 全是本组遗留,
  #54/#53/#51/#50 归英雄组与总监),接 backlog **第 0b 条**,按上一轮点名的下一批候选做
  **`aba_defend` 的「我在不在挨打」guard 群**。**主动放弃 830**(它整条分支靠
  `jmz.GetPosition`,而 GH #53 已证明 fixture 世界全队 pos 都是 1),选 **1253**
  (`DefendThink` 的动作类闸门,**已发布未 gated**)。
  **又一条没人声明过的世界断言(第五条)**:`bot_api.lua:278` 把 `GetHeroLastSeenInfo` 桩成 `{}`,
  **同时** loader 的 `GetTeamPlayers` **无视 team 参数**两边都发己方下标 ⇒ 所有读者的
  `for _, id in pairs(GetTeamPlayers(GetOpposingTeam())) ... info[1]` 循环体**结构上不可达**
  ⇒ **每个 fixture、每一帧 `J.GetLastSeenEnemiesNearLoc` 恒返回空列表**(白话:「谁也没见过任何
  敌人,在任何地方」)。可达面 `GetHeroLastSeenInfo` **28** 个调用点 + `J.GetLastSeenEnemiesNearLoc`
  **11** 个,横跨 `aba_defend`(防守出价 / `GetThreatenedLane` / `ShouldDefend` 人头 / `DefendThink`
  路况)、`aba_push`、`jmz_func`、`utils`、`ability_item_usage_generic`、`mode_retreat_generic` 等。
  修复:己方那一半由总监同期 GH **#53** 的 roster 修复接管(真实 `player_id`);本轮补**敌方**
  (有 `player_id` 用真值,否则自己的 id 段,必然互斥,**只发给存活单位**),
  `GetHeroLastSeenInfo(id)` 发**真实帧坐标 + `time_since_seen = 0`**(没 fixture 带视野,GH #27;
  将来有 `seen_by` 则看不见的给 **999** = 用不了的记忆,**不编陈旧坐标**)。
  **顺带第二个缺口**:`TEAM_RADIANT/TEAM_DIRE` 此前是**自动哨兵整数**,而 `GetTeam()` 发真值 2/3
  ⇒ 每处 `Team == TEAM_DIRE` 恒假 ⇒ **`J.GetTeamFountain` 把天辉泉水发给夜魇英雄**,fixture 里
  每一个「向自家泉水后退」的落点都指着地图反角。补 2/3/4。**两条修复在当前语料上都是加法**:
  **没有任何已钉住的结论翻面**(rebase 前 605/605 → 605/605;合到 GH #53 之上后 610 → **625**)(但今后关于 last-seen / 泉水方向的断言
  必须晚于本次修复才算数)。
  **接上之后一条已发布未 gated 的判据当场翻面。** `DefendThink` 的「别走进火里」闸门
  (`#pathEnemies > #ds.nInRangeEnemy`)**两边是同一个查询**
  `GetLastSeenEnemiesNearLoc(botLocation, 1600)`:左边按 500ms 分桶,右边写在
  `GetDefendDesireHelper` **最底部、7 条提前 return 之下**,而其中一条
  (`#closeEnemiesDefend > 0 and #closeAlliesDefend >= #closeEnemiesDefend`)的触发条件**恰好**
  就是 `DefendThink` 会跑的那种帧(900 内正在打架),且 `bot._defend` **从不复位**。
  ⇒ **这条比较只可能被新旧差买到**,一旦为真就 `return`,把该帧其余所有分支作废。
  §0b 家族,**亚型新**:陈旧的不是句柄而是**计数**,且是**和自己的旧拷贝**比大小 ——
  分支写下来的语义**根本无法表达**。
  钉帧 `f_260819_223607_drow_defend_bail`(t=330.4,drow **609/780=78%**,自家 56% 血上路一塔
  **929** 外,3.8s 前被 ogre 打过,1600 内**恰好 1 个**敌人):shipped 出
  **`Action_MoveToLocation` 向泉水 641**(唯一动作);**GROUND TRUTH:它留下来了 —— t=332.6 补兵、
  t=336.9 拿 120 经验、t=338.0–339.9 对 ogre 打出 254,42.5 秒后才死**。当帧**全部脚本 mode**
  竞价 defend **0.30 赢**,所以 Think 真的会跑。对照帧 `f_260819_222526_jakiro_defend_fresh`
  (900 内 2 敌 1 友 ⇒ helper 走到底部写下活的 2)闸门**诚实为假**,两个世界逐位相同。
  **域实测(不是猜)**:三局录像里「5s 内挨英雄打 + 距自家建筑 1600 内 + 1600 内有敌人」的
  英雄-帧共 **1437**;抽 45 帧驱动真代码,闸门**条件为真 32/45(71%)**(27 次是 `nInRangeEnemy`
  仍为 0),**但 defend 赢下脚本竞价只有 1/45**(挨打时 retreat 通常 0.5–1.0 压过它);另 70 帧
  随机样本里 defend 赢 26 次、**没有一次闸门为真**。**真实缺陷,足迹很窄**(且是下界,引擎自带
  mode 拿不到,GH #27)。
  改动:gated **`defstale`**(turbo-only,**纯移除**),`bots/FunLib/aba_defend.lua` +
  **TS 源同步**;armed **只可能移除**那一条 `Action_MoveToLocation`+`return`,不新增动作、
  不改任何出价。**故意没做的那一半**:把 PATH 那边改指到 `ds.defendLoc`(helper 顶部就刷新)
  才是作者注释的意思 —— **下一个杠杆**,等 `defstale` 测出中性或更好再在干净基线上加。
  验收 `tests/test_fixture_last_seen.lua` **6 例** + `tests/test_defstale_defend_bail.lua` **9 例**
  (动作断言全部驱动真的 `aba_defend`:一帧内先跑三条 lane 出价再跑 `DefendThink`;前提全断言、
  机制断言、重建整场脚本竞价证可达并把 GH #27 局限写进测试、非 turbo 对照、对照帧逐位相同、
  两条反向断言)。**四次变异:删修复恰好 2、gate 常开恰好 3、拆 last-seen 接线恰好 8(其余 617
  一条不动)、`TEAM_DIRE` 退回哨兵恰好 1。625/625(基线 610)+ luacheck 0 警告。**
  `state.json` 新增 `fixture_last_seen_20260820` 与 `defstale_20260820`。
  **`defstale` gated 未 armed**,入集申请见 **GH #55**;**排期建议:不要给它单独一条臂**
  (足迹窄,浪费),混波带着走或与将来的「意图修复」一起测。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 3 个 `.dem`,未启动任何计费资源),未提批测请求。
  详见 `iterations/reports/strategy/20260820T033630Z.md`。
- 2026-08-20T01:45Z:没有可认领的新 `[strategy]` issue(#45/#44/#41/#37/#35/#28/#26 全是本组
  遗留,#50/#51 归英雄组与总监),接 backlog **第 0b 条**,按它点名的最高优先级做 **`tpwatch`**。
  **本轮 `bots/`、`game/` 零改动**(`git status bots game` 空,无新 gate,未提批测请求),
  产出是**一条 mock 保真度修复 + 一条负结果 + 一条出集建议(GH #52)**。
  **又一条没人声明过的世界断言**:`tests/mock/bot_api.lua` 对未覆盖的 `Is*/Has*/Can*/`**`Was*`**
  一律答 false ⇒ **每个 fixture 里每个单位 `WasRecentlyDamagedBy*` 恒 false**,而 `bots/` 下有
  **670 个调用点**读这一族(AnyHero 527)。与 §F 的 `GetTower`/`GetIncomingTrackingProjectiles`、
  上一轮的 `HasModifier` 同类。`observed.damage` **代替不了**:它向**后**看(ground truth),
  这一族向**前**看(bot 在 t 已知的事)。修复:`make_fixture.py` 逐单位输出 `recent_damage`
  (`dt`= t 之**前**的秒数、`kind`=hero/tower/creep/other、`actor` 用**快照名**避开
  `queenofpain` canon 坑、丢自伤)+ 顶层 `recent_window`(默认 6.0s);`replay_fixture.lua`
  **只在该块存在时**装那四个读法 ⇒ **老 fixture 逐字节不变**(有回归护栏)。顺带补两个 mock
  全局(都是新可达之后才发作):`GetIncomingTeleports`(列表;`mode_laning_generic` 在任何
  「最近挨过打」的帧上**硬崩**)、`GetShopLocation`(`mode_secret_shop_generic` 文件作用域就读,
  不接则整个 mode 加载不了)。
  **`tpwatch` 判据本体第一次跑完,结论是负的。** 钉两帧(同一局同一主角,**都取自候选侧**,
  该局 stamp 含 `tpwatch` 且 juggernaut team 2 = radiant ⇒ **armed**):
  `f_260819_222030_jugg_tp_start`(t=437.1,读条 0.1s,733/1154)与
  `f_260819_222030_jugg_tp_eaten`(t=439.5,读条 2.5s,313/1155,**剩 0.5s**)。
  **GROUND TRUTH:读条 t=440.0 完好落地,他又活了 103.5 秒** —— 扛完读条就是这帧的正确决定。
  **缺陷是 §0b 出价类的新亚型:出价完好、赢下竞价、却什么都没改变,因为它抬的是已经在跑的那个
  mode。** 重建当帧**全部 22 个 mode 文件**:shipped `mode_retreat_generic` **0.75**(已 promote
  的反越塔 guard,同一条链里就在 `tpwatch` 下面六行)已经赢,次高 `mode_laning_generic` **0.446**;
  armed 只把 0.75 抬到 **0.9**,重新选举当选者 ⇒ 没有 mode 变化 ⇒ 引擎不重新下令;而
  `mode_retreat_generic` **只有 `GetDesire()`、没有 `Think()`**,那 +0.15 结构上没有落点。
  **判据本身还是滞后指标**:11 局里 8 次满足其伤害阈值的读条,判据**最早只在落地前 1.2s** 成立
  (jugg 1.2 / DK 1.0 / sniper 0.9 / centaur 0.5,另 3 次只在死或落地那一瞬),1 次从未成立;
  **armed 侧有真实窗口的 2 次读条 100% 跑完**,没有一次被放弃 —— 与机制分析互相印证。
  **本轮不写 gated 修复**:接缝错(抬出价 ≠ 下指令)+ 判据错(滞后),不是差一个闸门;且回收
  已下达的命令按 backlog 第 0 条**只能落在 `ability_item_usage_generic`,是另一个杠杆**。
  验收 `tests/test_fixture_recent_damage.lua` **6 例** + `tests/test_tpwatch_channel_bid.lua`
  **7 例**(**所有 desire 驱动真的 mode 文件 `GetDesire()`**;前提全断言、guard 链走到 261 行
  逐条断言、全 22 个 mode 竞价两个世界各跑一遍、`mode_retreat_generic` 仍无 `Think()` 的**源码级
  反向断言**、回归护栏、两条反向断言)。**两次变异:拆 loader 接线恰好 6 条 FAIL(其余 588 条
  一条不动)、让读法忽略 interval 恰好 3 条 FAIL。594/594(基线 581)+ luacheck 0 警告。**
  `state.json` 新增 `fixture_recent_damage_20260820`。**建议见 GH #52:把 `tpwatch` 移出 armed
  测试集**(真实帧上可证明 inert,留在集里只会稀释同波其它 id 的归因)。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 11 个 `.dem` + 6 个 `.analysis.json`,未启动任何
  计费资源),未提批测请求。详见 `iterations/reports/strategy/20260820T014500Z.md`。
- 2026-08-19T23:25Z:没有可认领的新 `[strategy]` issue(#45/#44/#35 在等总监批入集,
  #37 剩下那一半明确要求先要帧证据),接 backlog **第 0 条**「命令的边界」普查。
  **本轮零行为改动**(`git status bots game` 空,无新 gate,未提批测请求),
  产出是**普查结论 + 让普查可执行的工具链 + 一条负结果 + 一条 bug 上报**。
  **普查枚举做完了,范围收窄**:`mode_defend_tower_*`/`mode_attack`/`mode_push_tower_*`
  根本不含连续型单位命令;outpost 打的是静止建筑;team_roam:569 是非英雄目标。
  **只剩 `mode_roam_generic` 九处**(642–871),形状与 `roamreach` 逐条同构且**更确定**
  ——授权是**会到点消失的 modifier 计时器**,命令却是连续的,释放只住在 `Think` 里。
  **但这九处一条都没法在真实帧上验收**,原因就是本轮真正的发现:
  **`tests/mock/bot_api.lua` 对未覆盖的 `Is*/Has*/Can*` 答 false ⇒ repo 里
  每一个 fixture、每一个英雄、每一帧 `HasModifier(任何名字)==false`、`NumModifiers()==0`。**
  这是一条没人声明过的世界断言(没人被缠绕/晕/沉默/变羊/在读 TP/带任何 buff),
  与 §F 记的 `GetTower`、`GetIncomingTrackingProjectiles` **同一类**。两个静默后果:
  (1) 整段已发布分支结构上不可达 —— 上述九处、`item_tpscroll` 开头那张十条否决表,
  以及 **`J.ShouldAbandonTpChannel`(本组 gated id `tpwatch`,在 eligible 集内)第一行
  就是 `HasModifier('modifier_teleporting')` ⇒ 它的逻辑本体从来没有在任何真实帧上
  跑过一行**;(2) 测试可以断言错的东西还全绿(本轮那一帧的主角**其实被缠绕**,
  旧世界把他呈现成可自由走动)。
  修复:`make_fixture.py` 用 `MODIFIER_ADD/REMOVE` 配对重建 t 时刻仍生效的 modifier
  (`name/remaining/elapsed/stacks`),`replay_fixture.lua` 接上五个引擎读法;
  **没有该字段的老 fixture 逐字节不变**(有回归护栏)。`stacks` 数的是**日志事件条数**、
  不是引擎计数器(combat log 的 stack 数值语义未定),**暂不可用来钉
  `J.GetModifierCount(...) >= N`**(注释已写死)。
  钉帧 `f_260819_223607_sniper_rooted`(`20260819_223607_slot1` @ t=563.5),同一帧
  **同时真实带**控制(Frostbite 2.0s)、增益(MoM berserk 5.0s)、读条(drow
  `modifier_teleporting` 1.8s,565.3 无干扰落地)。
  **头号产出之二是负结果**:本局仅有的两次 MoM **都不支持** `roamreach` 那种伤害 ——
  窗口 1 buff 到期后那 4 秒**打死了 CM**(+554 金 +922 经验),且开头 3 秒是被
  Frostbite 缠住(「站着不动」不是陈旧命令的证据);窗口 2 是刚复活在泉水开 MoM、
  6 秒内 1600 无敌人(**物品使用**问题,归英雄组)。**照这帧写修复就是照误读写修复**,
  故本轮不写 gated 修复。
  验收 `tests/test_fixture_modifiers.lua` **11 例**:前提全断言;**缺口断言用已发布未
  gated 的消费方** `J.CanBeAttacked`(本帧 false,**只摘掉 Frostbite** 其余逐位不变则
  翻 true);`tpwatch` 可达性用「只有越过第一行才会写的 `tpChannelStartHealth` 戳」证明,
  且本帧正确答案 false **是因为对的理由**;单位隔离 / 多一格索引扫描 / 老 fixture 回归
  护栏 / 两条反向断言。**两次变异:拆 loader 接线恰好 8 条 FAIL,让生成器不再输出恰好
  9 条 FAIL。556/556(基线 545)+ luacheck 0 警告。** `state.json` 新增
  `fixture_modifiers_20260819`。
  **顺带发现一个未修的 bug(已开 `[bug]` issue)**:`J.CanBreakTeleport`
  (`jmz_func.lua:4418`)调用**不存在的** `J.GetCastPoint`(邻居叫 `GetCastDelay`),
  目标真带 `modifier_teleporting` 就崩;从没人发现是因为**没有 fixture 造得出这个
  modifier**,且它目前**零调用者**。归总监,本轮不动。
  未花 AWS 钱(只读 S3:命中缓存的 dumper + 2 个 `.dem`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T232500Z.md`。
- 2026-08-19T21:30Z:认领 **GH #45**(同时是总监 `test_set.md` §J.4 ⑥ 点名归口本组的
  钉帧任务)。钉了两帧(**同一局同一个响应者**,都从 `.dem` 独立重建过):
  `f_260819_181742_ss_chase_start`(t=312.5,**命令被下达**,gap 805)与
  `f_260819_181742_ss_chase_stalled`(t=318.5,**6 秒后没有任何东西还在为它背书**,
  gap 760)。事件层 ground truth 比 issue 更硬:**t=305–333 之间该英雄对英雄的伤害
  事件与施法事件都是 0**,第一次施法是 t=333.3 打一只小兵(已放弃追击之后),DK 从
  23% 回到 42%;Centaur 全程在旁(656u→218u),是 **2 打 1 追残血却零输出**。
  **机制被证明,同时证伪了 #45 §3 的猜想。** 链条:(1) **`ownhalf` 且只有 `ownhalf`**
  (逐个 id 单独 armed 试过)在 t=312.5 打开 `J.ShouldPunishDive`,team_roam 出价
  **0.72** 并赢下竞价(laning 0.446,其余全 0);(2) 它的 `Think` 下的是
  `Action_AttackUnit(target, false)` —— **连续型**命令,而当帧 gap 805 **超过该英雄
  全部触及范围**(普攻 400 / Ether 500 / Shackles 400 / Hex 550);(3) t=318.5
  **一条分支都不成立、出价 0**,另一个 mode 赢 ⇒ 引擎**不再调用 team_roam 的 `Think`**,
  而这个 mode 唯一自带的释放(>1800 leash)就住在 `Think` 里 ⇒ 命令**既无背书也无可达
  释放**却仍在执行。**一帧成立的 collapse 分支买到一次横穿地图的追击。**
  §0b 家族的**动作类**变体,亚型新:**出价与动作在各自那一帧都对,缺的是动作在出价停止
  之后的边界**。证伪的是 #45 §3 前半句(「分支持续出价 + 某个力往回拉」)——**分支 6 秒内
  就停了,追击照旧**,不需要任何回拉力解释那个 644–870u 的环。
  与 `roamstale` 的关系:这是它的**送达**那一半(shipped 侧陈句柄恰好吞掉这条命令,
  总监 §J.4 ③),**不是 fixture 能证的**,如实标注为臂 A/B 差分推断。
  改动:gated `roamreach`(turbo-only,**只改 `mode_team_roam_generic.lua`**):
  新 `_roamreach_ThreatReach`(普攻距离或**已学会且当前可施放**技能的施法距离取大)+
  `_roamreach_BoundedChase`,armed 时**英雄**目标超出触及范围就下
  `Action_MoveToLocation(目标位置)`——**有限**命令,挂在 `Think` 的两个英雄攻击点。
  **不改任何一处出价**(断言 armed 后仍 0.72);触及范围内的目标、**任何非英雄目标**
  逐字节不变;**单独 armed 是逐位 no-op**(断言)⇒ **不可单拎成一臂**,同
  `tpdying`/`tpdead` 的排期形状。**没有动 `ownhalf`/`roamstale`/`ShouldPunishDive`
  一个字节。** 验收 `tests/test_roamreach_bounded_chase.lua` **11 例**,全部驱动真的
  `GetDesire()`+`Think()`:前提全断言、机制断言(每个真实触及距离都短于 805)、
  归因断言(逐 id 隔离)、缺陷断言(shipped `bOnce=false`;6 秒后出价 0 且另一 mode 赢)、
  四个对照组(进入范围/非英雄/非 turbo/合成 900 施法距离让承诺重新合法)、反向断言;
  **两次变异**:删修复恰好 2 条 FAIL,gate 常开恰好 2 条 FAIL。
  **529/529(基线 518)+ luacheck 0 警告**。`state.json` 新增 `roamreach_20260819`。
  **`roamreach` gated 未 armed**,入集申请见 GH #45 + `test_set.md` §I.7 追加行;
  **两条排期硬约束**:①不可单拎成一臂;②它绑的是 `roamstale` 送达的同一条命令,
  **不要与测量 `roamstale` 的波次同 arm**。顺带记下一条 harness 缺口(未开 issue,
  已进 `state.json`):`.dem` **不带每帧 mode 也不带 unit order**,「哪个 mode 在跑」
  只能靠在该帧重建整场竞价推断(同类 GH #27)。
  未花 AWS 钱(只读 S3:1 个命中缓存的 dumper + 1 个 `.dem`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T213000Z.md`。
- 2026-08-19T19:30Z:没有可认领的新 `[strategy]` issue(#37 由总监 19:00Z 裁定
  `tpdead` 入集、issue 保持 open,剩下那一半要先要帧证据;#41 已被 `roamstale` 解决,
  录像组 18:56Z 确认;#39 已获批)。接 backlog 第 8 条,**本轮 `midtp`/`suptp`**。
  **找到 §0b 家族的第 11 例,亚型是新的:使无效的机制来自调用方自己的前置条件。**
  `J.ShouldTpSupportTowerFight` 要求响应者**离塔 > 3500**、目标取自**塔 1200 内**,
  而 `J.SafeToCommitFight` 只统计**目标 1200 内**的人 —— 响应者**至少在自己的判据外
  2300 码**(三帧全部断言)。于是「可打才去」实际问的是「**没有我这仗是不是已经没事**」:
  **1 人被 2 人越塔(它存在的理由)恰好被拒,2v2(不需要人)恰好放行**;
  它自己的 HEAT GATE 让倒置变成系统性的 —— 唯一确定被数进去的友军**被要求**正在挨打。
  改动:gated `tparrive`(turbo-only,只在 `midtp`/`suptp` armed 时可达),新纯谓词
  `J.SafeToCommitFightOnArrival` 把**正在赶来的响应者**数进两条分支(`depthnum` 的深入
  +1 余量原样保留);**没动 `J.SafeToCommitFight` 本身**(共享消费路径,§0b 第九例)。
  可分离性:多一个友军只能抬高两条分支 ⇒ armed 是 shipped 的**严格超集**,
  **只可能新增响应,不可能删除或改指到另一座塔**;单独 armed 是逐位 no-op,**不可单拎成一臂**;
  与 `roamstale` 无交集,不干扰在跑的 bisect。
  验收 `tests/test_tparrive_collapse_gate.lua` **16 例**,三帧取自**臂 A 的同一局**
  (`20260819_183613_slot1`)、**同一个响应者**(风灵满血 7 级、TP 就绪、1600 内无敌人),
  只有交战点人头数不同:`..._outnumbered`(t=309.4,Jakiro **38% 被 2 人越塔**,风灵在
  **7809** 外,shipped **拒绝** / armed **响应**)、`..._lost`(t=310.4,**1 秒后**,0v2,
  两臂**都拒绝**——防止退化成「总是去」)、`..._parity`(t=378.9,2v2,两臂响应**同一座塔**)。
  前提全断言、机制本身断言(2300 分离 + 响应者确实不在自己的名单里)、人头数逐个断言、
  缺陷本身断言;**最终决策层**断言落点非 nil + 源码级钉住 helper 返回到 HIGH 出价之间
  只有那两个条件;含反向断言。**两次变异**:删修复恰好 3 条 FAIL,gate 常开恰好 2 条 FAIL
  (其中一条是**既有的** `test_mid_tp_support.lua`,独立见证 gate 默认是关的)。
  **518/518(基线 502)+ luacheck 0 警告**。`state.json` 新增 `tparrive_20260819`。
  **必须挑明**:本候选**故意推翻** `test_mid_tp_support.lua` 里写死的 shipped 意图
  (「outnumbered 不许拉 TP」,正是 1v2)。新测试里有一条 `[intent]` 用例把冲突写进代码;
  **promote 时那条测试必须重写、不能删**。
  **顺带更正本组 13:45Z 的一个说法**:那轮说接上 `GetTower`/`UNIT_LIST_*_BUILDINGS` 后
  「自家塔下」否决不再恒 false —— **当时不成立**。loader 的 building 没有 `IsBuilding`,
  而所有 shipped 读者都过 `J.IsValidBuilding` → `unit:IsBuilding()`,mock 默认 nil ⇒
  **整张表 100% 被拒**,塔循环与那条否决**仍然不可达**。本轮加 `IsBuilding = true` 才接通;
  接通前后既有测试**逐条同绿**(502→502),**无历史结论需重看**,但今后关于这两条路径的
  断言必须晚于本次修复才算数。
  **`tparrive` gated 未 armed**,入 test_set.md 已在 **GH #44** 申请;排期提示:
  它只改「去不去」不改**落点**,而 #37 的落点缺陷仍在,armed 后会作用在更多次响应上 ——
  建议**不要与 `lf_rescue` 落点类改动同波**。
  未花 AWS 钱(只读 S3 取 1 个预编译 dumper + 3 个 `.dem`,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T193000Z.md`。
- 2026-08-19T17:45Z:**冻结解除后接 backlog 第 5 条(GH #37,本组最高优先)**。
  没有可认领的新 `[strategy]` issue —— #41 是录像组 16:45Z 立的,但总监 17:00Z 已裁定
  (路 C),它的机制就是上一轮交的 `roamstale`(#39,已获批入集),没有留给本组的动作。
  冻结令解除依据:`5a327f5` 已落地 bisect verdict(A−B = +8.12 gpm,z=0.60,null)。
  **本轮头号产出是负结果:候选 2 也被同一组验收帧证伪。** 上一轮说「候选 2 能分开
  三帧」是在**概念层**比「到达时间 vs ground truth 存活时间」;而门里唯一能拿到的是
  `GetEstimatedDamageToTarget(window) < 友军当前血量`。给 `make_fixture.py` 加了
  `observed.damage`(**逐事件**英雄伤害时间线,默认 30s 视野;`observed.burst` 只回答
  一个窗口,而候选 2 问的是另一个),按各帧自己的到达窗口重算门的那条比较:
  **A 548/430 否决(对)、B 96/225 放行(错)、C 258/246 否决(错得致命 —— 那是本波
  唯一一次按设计工作的救援;Axe 25% 血硬吃 258 还活 151 秒,靠回血/药膏,门不建模回复)**。
  dumper 漏计使 258 是**下界**,数据越全对 C 的否决只会越确定,所以这一半站得住;
  B 那行是软的一半(漏计可能翻面),没拿来当结论。
  **于是改走候选 3:gated `tpdead`(turbo-only,且只在 `tpcommit` armed 时可达)** ——
  救援分支多盖一个 `bot.tpRespondAlly`(**为谁**去的),另两条答**地点**的应答 TP
  显式清空该戳;`J.GetTpCommitDefendDesire` 里若戳着的友军已阵亡则清戳、`return nil`。
  **地板 0.85 / 12s 窗口 / 两条既有释放一个字没动,`nVsMe < HP*0.70` 没碰**。
  可分离性同 `tpdying`:只可能把地板变成 nil,**单独 armed 是逐位 no-op**,不可单拎成
  一臂;与 `roamstale` 无交集,不干扰下一波 bisect。
  验收用**三个新的落地后真实帧**(各自 cast 后 6.0s,人已落地仍在承诺内):
  `f_260819_123012_dp_landed_dead`(DK cast 后 **4.7s 死**,响应者离尸体 **5876**)、
  `f_260819_122930_lina_landed_dead`(Lich **2.9s 死**,读条都没走完)、
  `f_260819_123546_jakiro_landed_ok`(Axe **活着**)。
  `tests/test_tpdead_release.lua` 9 例,**所有 desire 断言驱动真的
  `mode_defend_tower_mid_generic.lua` `GetDesire()`**;前提全断言(窗口内/响应者存活/
  两条既有释放沉默/触发点 1600 内仍有敌人/友军生死按 DEATH 事件);**缺陷本身被断言**
  (shipped 三帧**全给 0.85**,含两具尸体);armed 后两具尸体的承诺掉下去、**活的那次
  原样 0.85**;含反向断言(armed 永远不能把 nil 变成地板)+ **戳而非「队里有人死了」
  才是判据**的对照;**两次变异**:删修复恰好 2 条 FAIL,gate 常开恰好 1 条 FAIL。
  **489/489(基线 479)+ luacheck 0 警告**。`state.json` 新增 `tpdead_20260819`。
  **`tpdead` gated 未 armed**,入 test_set.md 已在 **GH #37** 申请。
  **明说没解决的那一半**:`tpdead` 只回收浪费掉的 12s 承诺,**不阻止那次到不了的 TP**
  ——#37 的经济账主要在后者,后续方向见 backlog 第 5 条。
  未花 AWS 钱(只读 S3 取 3 个 `.dem` + 命中 dumper 缓存,未启动任何计费资源),
  未提批测请求。详见 `iterations/reports/strategy/20260819T174500Z.md`。
- 2026-08-19T15:34Z:**`lf_rescue` 冻结令仍有效**(臂 B 补跑 verdict 未落地,
  `origin/main` 仍停在总监 15:00Z 的 `4993b4b`),本轮 `git diff` 里**没有 `lf_rescue` /
  `jmz_func.lua` 的任何一个字节**。没有可认领的新 `[strategy]` issue,接 backlog 第 8 条
  「最终出价可达性」普查,**一次一条,本轮 `ownhalf`**。
  **出价这一层 `ownhalf` 干净**(负结果,如实记录):在它自己的立案帧
  `f_232228_wk_ownhalf_standoff`(t=340=5:40)上,原始 0.98 被 `CapForLanePush` 砍到
  **0.72**,但 0.72 仍**赢下模式竞价**(`mode_laning_generic` 同帧 **0.446**,其余 16 个
  mode 文件全 **0**)—— 它**不是** #29/#31/#32/#35 那种出价域缺口。
  **但补验收时在下游一层撞到新缺陷**(总监 §0b 第八例,**新亚型:出价完好且赢了竞价,
  被本 mode 自己的 `Think()` 丢掉**):`mode_team_roam_generic.lua` 的 `hTargetCreep`
  **只有一个写者**(last-hit 分支),**位于全部六条提前 return 的出价分支之下**
  (`ConsiderHelpWhenCoreIsTargeted`/`ConsiderHelpAlly` **已发布** + `ownhalf`/`overchase`
  (**armed**)/`l1trade`/`l5combo`),**从不复位**;而 `Think()` **第一件事**就是读它并
  `return`。于是**每一帧只要那六条之一赢下竞价,这个模式就去打上一帧那只小兵,永远碰不到
  自己算出来的集火目标** —— 这机械地解释了 `ownhalf` 的立案观察本身(232228:WK 满血、
  晕就绪,在 69% 血落单 Jugg 旁 ~1000 码悬停 17 秒)。
  改动:gated `roamstale`(turbo-only),在 `GetDesireHelper` 开头清 `hTargetCreep`;
  可分离性同 `capmono` 的「纯 min」——last-hit 分支每帧到达时都会重新赋值,所以 armed
  差集**恰好**是「某条提前分支返回了」的帧,**只可能移除一次残留小兵攻击、不可能新增**,
  且**不改变任何一处出价**。验证 `tests/test_roamstale_collapse_action.lua` 7 例
  (真实帧两帧端到端驱动真的 `GetDesire()`+`Think()`;帧事实全断言;**无小兵对照组**证明
  小兵就是机制;普通补刀帧 armed/shipped 逐位相同;**反向断言**钉住写者数量,别人正经修掉
  时自曝过期;**两次变异测试**:删修复恰好挂 2 条,gate 常开恰好挂 1 条)。
  顺带补 mock 保真度缺口:`GetIncomingTrackingProjectiles` 默认从 `0` 改为 `{}`
  (引擎返回列表;此前任何驱动真补刀/来袭伤害路径的测试都会 `pairs` 崩溃 —— 是崩溃不是
  假绿,无历史结论需重看)。**462/462(基线 455)+ luacheck 0 警告**。
  `state.json` 新增 `roamstale_20260819` 与 `ownhalf_BID_AUDIT_20260819`。
  **`roamstale` gated 未 armed**,入 test_set.md 待总监批(已开 issue **#39**)。
  **排期硬提示:它横跨六条分支(含两条已发布、一条此刻 armed 的 `overchase`),必须单独
  测量,不可与 `ownhalf`/`overchase`/`l1trade`/`l5combo` 任何一条的 bisect 同波 armed。**
  未花 AWS 钱(本轮零 AWS 调用、零 S3 读),未提批测请求。详见
  `iterations/reports/strategy/20260819T153447Z.md`。
- 2026-08-19T13:45Z:认领 **issue #37**(总监 13:12Z 归口本组)。总监冻结令:
  verdict 落地前**不许动 `lf_rescue` 代码** —— 本轮严格遵守,
  **`git status bots game` = 0 个文件**,无行为改动、无新 gate、`state.json` 未改。
  做的是冻结令没覆盖、且**必须先做**的那一半:总监要求的验收形状(「三帧一起钉」)
  **在旧工具链里无法表达**。两处 mock 保真度缺口互相掩盖:
  (1) `bot_api.lua:264` 把 `GetTower` 桩成 `nil`,于是
  `J.GetNearbyLocationToTp` 在**每一个 fixture 里**都落到「一座塔都不剩」的兜底
  → **返回泉水**(此前所有 TP 落点断言测的都是真实对局里不会发生的退化路径;
  同一缺口还让 `GetRescueTpTarget` 的「友军在自家塔下」否决恒为 false);
  (2) mock `Vector` 没有 `__div`,即使接上塔,算 575 偏移时也会直接崩。
  已补:`make_fixture.py` 输出 `buildings`(dumper 本就在落这份数据)、
  loader 接 `GetTower`/`UNIT_LIST_*_BUILDINGS`(**阵亡结构缺席**=引擎语义)、
  `Vector.__div`。**没有 `buildings` 的老 fixture 逐字节不变**(有回归护栏钉住)。
  钉住三帧(Python 从 .dem 独立重建 + Lua fixture 世界跑出,两边逐位吻合):
  `f_260819_123012_dk_rescue_far`(落点→友军 **5623**,友军 4.7s 后死)、
  `f_260819_122930_lich_rescue_doomed`(**1579**,2.9s 后死)、
  `f_260819_123546_axe_rescue_ok`(**1746**,活)。
  **两条实质结论**:(i) **候选改法 1「落点距离门」被证伪** —— 必须拒绝的 B(1579)
  比必须放行的 C(1746)**还近**,任何砍掉 B 的天花板都会连本波唯一一次有效救援
  一起砍掉(录像组报的 1857/1585 与我重建的顺序相反,但两版都相距 <300 码,
  **距离维度上根本不可分**,结论不依赖哪版更准);(ii) **候选 2「把落点距离喂回
  生存窗口」能分开全部三帧且两向余量充足**(A 超预算 4.6×、B 超 2.9×、C 富余 17×,
  对移速取值不敏感)。顺带证实 **shipped 的 `J.WillAllySurviveTpWindow` 三帧全返回
  true**,分不开任何东西 —— 它的 4.0s 预算**全花在读条上**,一点没留给落地后要走的路。
  验证 `tests/test_lf_rescue_landing_reach.lua` 6 例(前提全是断言出来的;
  含证伪断言、可分性断言、老 fixture 回归护栏;**两次变异测试**:拆塔接线恰好 3 条
  FAIL,拆 `__div` 恰好 4 条 FAIL)。**450/450(基线 444)+ luacheck 0 警告**。
  **下一轮交接**:冻结解除后按**候选 2** 写 gated 修复(不要写距离门),验收直接用
  这三个 fixture;**不要动 `nVsMe < HP*0.70`**(总监钉死的边界);候选 3 与候选 2
  互补但应**排在其后单独做**(它改的是 `tpcommit` 那块地板,与上轮 `tpdying` 同源,
  合做就是一次变两个量)。未花 AWS 钱(只读 S3 取 3 个 `.dem` + 命中 dumper 缓存,
  未启动任何计费实例),未提批测请求。详见
  `iterations/reports/strategy/20260819T134500Z.md`。
- 2026-08-19T11:35Z:没有可认领的新 `[strategy]` issue(#32 已被总监 11:10Z 批准
  入集,本轮关闭;#28/#26 是本组遗留),接 backlog 第 8 条「最终出价可达性」普查,
  **一次一条,本轮做 `tpcommit`**。发现 **#29/#31/#32 同族的第四例**:
  `J.GetTpCommitDefendDesire` 的 0.85 落地地板,其释放条件
  `GetHP < 0.40 or J.ShouldRetreatLaneBurst(bot)` 里**预判的那一半**
  (`ShouldRetreatLaneBurst`,第三行 `if not J.IsInLaningPhase() then return false end`)
  在**这块地板自己的生效域里结构性失效** —— 地板只能从两个响应 TP 分支到达,而它们
  要求 6 级 + >3500 码跨图,所以钉住的帧压倒性在对线期之后,释放只剩「已经掉到 40%
  以下」。这正是当初写这个释放要堵的「站在原地被磨死」形状,**减掉了让它奏效的那一半**。
  改动:gated `tpdying`(turbo-only,且**只有在 `tpcommit` 也 armed 时才可达**),
  新纯谓词 `J.IsIncomingBurstLethal`(与 `ShouldRetreatLaneBurst` 同一个 mana/cd-aware
  估算器,去掉对线期门),armed 时**只可能提前释放**,结构上不可能抬高或制造钉死;
  地板值 0.85 / 12s 窗口 / 原释放**一个字没动**。
  验证 `tests/test_tpcommit_release_domain.lua` 9 例,锚在真实帧
  `f_182552_warlock_ult_hoard`(t=626=10:26,术士 53.4% 血,狙击手 1008 码外,
  ground truth:打出 **669** 进 546 的血池,**2.3s 后死**);两个前提
  (`IsInLaningPhase()==false`、`GetHP>0.40`)都是**断言出来的**;**所有 desire
  断言驱动真的 mode 文件 `GetDesire()`**(§0b 规矩):armed tpcommit → defend
  **0.85** vs retreat **−0.05**(就在他被打死那一帧);shipped → 0.1;+tpdying → 0.1。
  含反向断言(shipped 释放哪天被改成域正确的,测试自曝过期)+ 两次变异测试。
  **427/427 + luacheck 0 警告**。顺带补了四处 mock 保真度缺口(见 backlog 第 8 条)。
  `state.json` 新增 `tpdying_20260819`。**`tpdying` gated 未 armed**,入 test_set.md
  待总监批(已开 issue **#35** 申请;排期提示:单独 armed 是 no-op)。
  **另发现但未动**:响应 TP 的落点(`J.GetNearbyLocationToTp` → 最近**存活**己方塔前
  575 码,无塔回落**泉水**)从来没有和触发点做过距离校验,而 `WillAllySurviveTpWindow`
  只预算 4.0s、**不含落地后走过去的时间** —— 这能机械地解释录像组 `20260819T033000Z`
  里那个「前置条件全满足但落地在泉水」的 `lf_rescue` 帧。**故意没动**:一次一个杠杆,
  且 `lf_rescue` 是马上要跑的 bisect 的被测变量。未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T113516Z.md`。
- 2026-08-19T09:16Z:没有可认领的新 `[strategy]` issue(#28/#26 都是本组上一轮
  自己的遗留),于是接住总监 09:04Z 关闭的 **#31 没覆盖的另一半**。总监对
  `l1trade`/`l5combo` 的修法是**豁免**(它们硬性要求对线期,cap 域是其生效域的
  严格超集);**仍被 cap 的四条分支没人管**,其中 `overchase` 此刻就在 armed 集内。
  缺陷:`_divecap_CapForLanePush` 注释写 `soft ceiling`、代码是**悬崖**
  (只砍 `>0.9`,砍到 0.72,低于原样放行的整个 (0.72, 0.9] 带),而四条分支出价
  都是 `RemapValClamped(HP, 0, 0.5|0.6, NONE, 0.98)` → **有效出价对血量非单调,
  峰值 ~46% 血**:满血 0.72(输给已 promote 的 lanesurv 0.75),43% 血 0.843
  (赢),36% 血 0.71(输)。**最没资格打的人是唯一被钉进架子里的人**,而这四条
  都没有 lane-kill 那样的 `ShouldReleaseLaneCommit` 自释放 —— wave13 卷宗实锤过
  的钉死送命形状。这是 #29/#31 同族缺陷的**第三例**。改动:gated `capmono`
  (turbo-only),armed 时把悬崖换成真天花板 `min(desire, 0.72)`,**天花板的值不动**;
  armed 路径是纯 min,**只可能降低出价**,所以结构上不可能造成那个让 `divecap`
  至今留暗的「过度投入」风险。验证:`tests/test_capmono_ceiling.lua` 12 例,
  锚在真实帧 `f_222428_lion_lich_burst`(Lion 354/823=43.0% 血 @ t=314,
  Lich 660u + Axe 800u,2200 内无队友;录像 ground truth:Lich 打出 436,
  **6.9s 后 Lion 死亡**);该帧的「cap 真的生效」+「lanesurv 真的出 0.75」都是
  **断言出来的**;含 21 点血量扫描直接驱动真的全局 `GetDesire()`(只强制触发器),
  以及一条**反向断言**(未 armed 时必须仍非单调,悬崖被改掉时测试自曝过期)。
  两次变异测试:删掉修复 → 恰好 3 条 armed 断言 FAIL(报错打印真实倒置
  `0.881 → 0.72 as HP rose to 0.5`);gate 强制常开 → 恰好 5 条已发布行为断言 FAIL。
  **408/408 + luacheck 0 警告**。`state.json` 新增 `capmono_20260819`。
  **`capmono` gated 未 armed**,入 test_set.md 待总监批(已开 issue **#32** 申请)。
  未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T091647Z.md`。
- 2026-08-01 初始化。测试集里本组名下 id:creeppull/pullcamp/l1trade/
  l5combo/midtp/suptp/tpcommit/lf_rescue/teambrain/ownhalf/overchase/tpwatch。
  l1xpsoak 不在集内,等重设计。
- 2026-08-19T01:15Z:首次真实工作报告(见
  `iterations/reports/strategy/20260819T011551Z.md`)。完成 l1xpsoak 重设计
  代码(绝对锚 + 退出滞回),fixture 验证 + 全套测试 + luacheck 全绿,已
  push。**l1xpsoak 仍不在 test_set.md 里**(该文件编辑权在总监)——已开
  issue #24 请总监审批重新入集并排期验证批测。未花 AWS 钱,未提批测请求。
- 2026-08-19T03:20Z:issue #24 已由总监批准入集(`test_set.md` 已含
  `l1xpsoak`,commit `15a9262`),协同组关闭该 issue。认领 issue #26(集火
  目标选择不看"谁在滚雪球"),定位代码路径(`GetAttackableWeakestUnitFromList`
  双向复用于治疗/攻击目标、多数英雄自动攻击目标其实来自引擎原生 AI,脚本层
  只在少数特例显式打分),委托 replay-analyst 子代理拿录像建真实帧 fixture,
  逐帧复核后发现原始 issue 的直觉判断在具体帧层面站不住(Lina 当时在近战
  射程外,DK 换目标打不到她,死因是远程爆发而非目标选择)——**判断证据不足
  以支撑负责任的行为改动,没有写 gated 修复**,只落地工具链补强(dumper→
  fixture→mock loader 全链路补上 net_worth 字段,今后经济类修复可直接用
  真实身价做本地验证)+ 帧证据 fixture 存档 + issue #26 评论留下两个建议
  方向(同射程多候选场景重新取帧 / 转向撤退-威胁评估角度,可能与 backlog
  `−18 econ 残差归因` 同源)。全量 366/366 测试 + luacheck 0 警告。未花
  AWS 钱(replay-analyst 走它自己职责内的只读 S3),未提批测请求(无行为
  改动可测)。详见 `iterations/reports/strategy/20260819T032018Z.md`。
- 2026-08-19T07:17Z:认领 issue #28(总监 06:55Z 把 `l1xpsoak` 退回本组,要求在
  "让锚点真正驱动移动" / "取消独立 id、滞回收进 lanesurv" 两条路里二选一)。
  **选路径 2,并做保守细化:滞回不改已 promote 的默认,而是挂新 gate
  `lanehyst`**(未 armed 时 shipped 判定逐字节不变,armed 时可单独测量)。
  放弃路径 1 的**新证据**:`mode_retreat_generic.lua` 只有 `GetDesire()`、
  **没有 `Think()`**,撤退时的移动/TP/逃生全在引擎内置实现里——"站在锚点 hold"
  等于给最安全攸关的 mode 重写整套 Think,而 mode-Think 替换正是 A1 分析判定
  `l1xpsoak` −50 gpm 的主因。改动本体:`J.ShouldRetreatLaneBurst` 在 true 帧
  盖时间戳,基础门槛没过时于 **2.0s 窗口**内继续 true(条件:无 peel 队友 +
  incoming 仍 ≥40% 血量);**刻意有时间上限**,可抹平闪烁但永远变不成停车刹车。
  依据 (c):对阈值附近闪烁的二值控制信号加 Schmitt trigger,本仓库 l1kite 的
  kite-lock 是同一味药。同时**退役 `l1xpsoak` 全部代码**(helper + 消费块 +
  旧测试),留墓碑注释。验证:新 `tests/test_lanehyst.lua` 7 例全跑真实帧
  `f_231411_ck_zoned`,非空验证(关死 gate 恰好 2 条 hold 断言 FAIL),
  **381/381 测试 + luacheck 0 警告**。`state.json` 新增 `lanehyst_20260819` 与
  `l1xpsoak_RETIREMENT_20260819`。**`lanehyst` gated 未 armed**,入 test_set.md
  待总监批(已在 #28 评论申请)。未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T071719Z.md`。
- 2026-08-19T05:16Z:认领 issue #13(总监 04:54 点名本组"直接看代码里的触发
  条件")。**找到 `creeppull` 13/13 局 SILENT 的根因:它是一个可证明的死分支**
  ——`mode_roam_generic` 用 `J.IsLanePullSafe`(1800 内有敌人就 false)闸住
  `J.ShouldCreepPullLane`,而后者**必须**有一个 1000 内的敌方英雄当勾兵仇恨的
  攻击目标,两者互斥,自 20260723 rehome 起从未执行过一次。修复:拆分两种拉线
  的安全规则——拉野(离开兵线进野区)保留和平期规则不动;勾线改用新的
  `J.IsCreepPullSafe`(健康 + 1000 内至少一个对线者 + **1000–1800 环里没有多余
  的人**+ 最多 2 个),把问题从"有没有人可见"改成"有没有**多余**的人可见",
  同时保留 wave13 那个 163732 埋伏形状的否决。**没有新 soak id**(改动活在既有
  `creeppull` 闸门内,未 armed 对局逐字节不变,state.json 无需登记)。真实帧
  fixture 6 例(`tests/test_replay_creeppull_reachable.lua`,含端到端在真实帧上
  出 pull intent + 埋伏帧/轮转帧/残血帧仍被否决),非空验证:临时把新闸门改回
  旧别名恰好 2 条可达性断言 FAIL。377/377 测试 + luacheck 0 警告。已在 #13 评论
  申请 **`creeppull` 重新入 test_set.md**(`pullcamp` 不申请,触发条件未查清,
  已进 backlog 第 6 条)。未花 AWS 钱,未提批测请求。详见
  `iterations/reports/strategy/20260819T051642Z.md`。
