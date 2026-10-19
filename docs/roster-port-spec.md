# 1918 — Roster & Livery Port Spec (v28 → v29)

**Reference:** `~/workspace/1918-ace-of-aces/1918-ace-of-aces.html` (563 lines; JS is minified into long single-line statements — "line N" below = the anchor line containing the statement).

**Scope:** 10 new enemy archetypes, Jasta squadron livery system, per-sortie wave weaving, battle-damage FX, luminous tracers, sim-loop smoothness. Builder ports via `artifact.edit` using the exact find→replace blocks in §A–F. No whole-file rewrites.

**LORE RULE (hard):** never write "Richthofen", "Red Baron", or "Manfred von" anywhere. The Dr.I / Jasta 11 lore refers only to **"the Crimson Ghost"**. (Verified: none of those strings exist in the file today; "CRIMSON GHOST MEDALLION" and minimap code `GHOST` are the existing convention — keep it.)

---

## 1. Analysis findings (what exists, where)

### 1.1 ENEMY_LIVERIES — line 313
`var ENEMY_LIVERIES=[{name:'STREAKED GREEN',base:'#546247',accent:'#9f352b',band:'#ece0b7',pattern:'streak'}, … 6 entries … {name:'BLUE NOSE',base:'#5c635b',accent:'#335772',band:'#e8d9ad',pattern:'dazzle'}];`

How liveries tint: `WaveManager.queueWave` picks `livery=(opts.livery===undefined?wave:opts.livery)%ENEMY_LIVERIES.length`, shifts per plane `(livery+i%2)%ENEMY_LIVERIES.length`, passes into `spawnEnemy` → stored as `e.livery`. Only live consumer today is the dead 3D path (`renderModels`, line 372, uses `enemyModelSource(e)` which returns `null` at line 371 — livery is currently **cosmetic metadata only** on the 2D sprite path). The 6th entry tail to append after: `…{name:'BLUE NOSE',base:'#5c635b',accent:'#335772',band:'#e8d9ad',pattern:'dazzle'}];`

### 1.2 Enemy archetype table + spawnEnemy() — line 442
```
function spawnEnemy(kind,opts){if(enemyRoom()<1)return false;opts=opts||{};kind=kind||'small';var livery=opts.livery===undefined?Math.floor(Math.random()*ENEMY_LIVERIES.length):opts.livery,squad=opts.squad||++squadronSerial,elite=kind==='triplane'||opts.elite,heavy=kind==='green'||kind==='riser',e={id:++entityId,x:-90,y:-90,vx:0,vy:0,r:elite?18:heavy?24:14,hp:elite?18:heavy?12:kind==='red'?4:3,max:elite?18:heavy?12:kind==='red'?4:3,phase:Math.random()*6.28,shoot:elite?.52:heavy?1.12:.9+Math.random()*.5,archetype:kind,ttl:99,route:'parametric',bank:0,livery:livery,squad:squad,elite:elite,rearGunner:heavy,pathState:{name:opts.path||'sine',t:0,delay:opts.delay||0,duration:opts.pathDuration||(elite?5.8:7.2),config:opts.pathConfig||{mirror:Math.random()<.5,phase:Math.random()*6.28,frequency:2.2,center:.5}}};advancePathEnemy(e,0);return addEnemy(e)}
```
Existing roster: **small** (hp 3, r 14, shoot ~0.9–1.4, single tracer), **red** (hp 4, r 14, single tracer), **green** (hp 12, r 24, shoot 1.12, 2-bullet fan + intended rear-gunner shot, rearGunner=true), **riser** (hp 12, r 24, shoot 1.12, 5-bullet heavy fan, rearGunner=true), **triplane** (hp 18, r 18, shoot 0.52, 3-bullet lead fan heavy, elite). Note the doctrine tension: standing 1942 damage doctrine says fixed hits-to-destroy; player twin bullets do ~1.0 dmg each at level 1 (`fireFrom`, line 435: `d:(1+.35*(level-1))*gunDamage`, gunDamage medium 1.12), so hp 3 = ~2 twin volleys, hp 12 = ~7 volleys.

**BUG FOUND:** `rearGunner` exists on green/riser, but the rear-gunner shot in the enemy-fire loop (line 479) is gated on `e.returning`, which is **never set to true anywhere** — the gold rear shot is dead code. (See grep: `returning` occurs only at line 479.) The spec's rumpler rear-observer pattern routes around this deliberately.

### 1.3 Wave/formation system — WaveManager line 321, spawnFormation() line 443
```
var WaveManager={queue:[],wave:0,lastElite:-99,maxWaves:18,patterns:['vee','beam','split'],paths:['loop','sine','swoop'],queueWave:function(opts){opts=opts||{};if(this.wave>=this.maxWaves&&!opts.force)return false;var wave=++this.wave,elite=!!opts.elite;if(elite&&(wave-this.lastElite<3||this.queue.some(function(q){return q.elite})||enemies.some(function(e){return e.elite&&e.hp>0})))elite=false;if(elite)this.lastElite=wave;var type=elite?'triplane':(opts.type||['small','green','red','riser'][wave%4]),size=elite?1:Math.max(4,Math.min(6,opts.size||4+wave%3)),livery=(opts.livery===undefined?wave:opts.livery)%ENEMY_LIVERIES.length,pattern=opts.pattern||this.patterns[wave%this.patterns.length],basePath=opts.path||this.paths[wave%this.paths.length],spacing=opts.spacing||.12,slots={vee:[[-.22,.18],…],echelon:[…],beam:[…],split:[…]}[pattern]||[];for(var i=0;i<size;i++){var slot=slots[i]||[0,0],path=i%3===2?this.paths[(this.paths.indexOf(basePath)+1)%this.paths.length]:basePath;this.queue.push({kind:type,delay:(i%2)*spacing+Math.floor(i/2)*.055,path:path,config:{mirror:!!((wave+i)%2),phase:i*.91,frequency:1.72+(i%3)*.31,center:.5+slot[0],radius:.15+Math.abs(slot[0])*.1,yOffset:slot[1]*H,xOffset:slot[0]*W*.12},livery:(livery+i%2)%ENEMY_LIVERIES.length,squad:wave,elite:elite,duration:elite?5.8:6.3+(i%3)*.55});}return true},update:function(dt){for(var i=0;i<this.queue.length;i++)this.queue[i].delay-=dt;for(var j=0;j<this.queue.length&&enemyRoom()>0;){var q=this.queue[j];if(q.delay>0){j++;continue}spawnEnemy(q.kind,{livery:q.livery,squad:q.squad,path:q.path,pathConfig:q.config,pathDuration:q.duration,elite:q.elite});this.queue.splice(j,1)}}}
```
`spawnFormation()` (line 443):
```
function spawnFormation(){if(WaveManager.queue.length||enemyRoom()<5||WaveManager.wave>=WaveManager.maxWaves)return false;var next=WaveManager.wave+1,elite=next%4===0&&next-WaveManager.lastElite>=3&&!enemies.some(function(e){return e.elite&&e.hp>0});return WaveManager.queueWave({elite:elite,size:2+Math.floor(progress.selected/8)+next%2,pattern:WaveManager.patterns[next%WaveManager.patterns.length]})}
```
- 1942 pacing (line 476): `if(spawnT<0){spawnT=spawnFormation()?(5+Math.random()*5)/difficultyProfile().wave:1.1}` — new formation every 5–10 s ÷ wave factor (medium 0.88 → ~5.7–11.4 s).
- **DISCREPANCY vs requested ramp:** `queueWave` clamps `size=elite?1:Math.max(4,Math.min(6,opts.size||4+wave%3))` — the `Math.max(4,…)` forces every non-elite wave to ≥4 planes, so `spawnFormation`'s 2–3 early size is **silently overridden to 4**. Actual sizes today: 4–6 flat. §C fixes this to 2→7.
- Elite gating: every 4th wave spawns a single `triplane` ace if no other elite alive and ≥3 waves since last elite. `WaveManager.update` drains the queue with per-plane delays through `enemyRoom()` (cap `MAX_ACTIVE_ENEMIES=10`, line ~312 area).

### 1.4 Sortie wave compositions
- `campaign` (line 239): 32 entries with `composition:{fighters:N,twoSeaters:N}`, `formation:'escort'`, `force:'1 SPAD · 2 HALBERSTADTS · 5 FOKKERS'` — **this field is never read by game logic** (grep `.composition` = zero hits outside the data). It's historical flavor only.
- `sortiePlans` (line 274): 32 entries `{bossAfter:95…,claimGate:6…,ground:[…],optional:{type,label,count},gas:bool,cues:[{at,kind,text}]}` — drives boss timing (`elapsed>plan.bossAfter&&kills>=plan.claimGate`, line 476), ground spawns, cue banners. **There is no per-sortie air-roster data** — the new `SORTIE_ROSTER` table in §C is additive; nothing to replace.

### 1.5 Bullet rendering — line 516 (draw())
Player:
```
bullets.forEach(function(b){ctx.strokeStyle=b.owner>2?'#b8f2ec':'#fff1a4';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(b.x,b.y);ctx.lineTo(b.x-b.vx*.018,b.y-b.vy*.018);ctx.stroke()});
```
No glow, no additive blending — plain 2px tracer streaks (p1/p2 warm `#fff1a4`, wingmen teal `#b8f2ec`).
Enemy:
```
enemyBullets.forEach(function(b){ctx.save();ctx.globalCompositeOperation='lighter';ctx.shadowBlur=10;ctx.shadowColor=b.style==='gold'?'#ffd76a':'#ff5a35';ctx.fillStyle=b.style==='gold'?'#ffe88c':b.style==='heavy'?'#ffddd0':'#ff754b';ctx.beginPath();ctx.arc(b.x,b.y,b.r,0,6.28);ctx.fill();ctx.strokeStyle='rgba(255,226,175,.7)';ctx.lineWidth=1.2;ctx.beginPath();ctx.moveTo(b.x-b.vx*.025,b.y-b.vy*.025);ctx.lineTo(b.x,b.y);ctx.stroke();ctx.restore()});
```
Enemy bullets already use additive `lighter` + `shadowBlur:10`. Enemy fire spawners: `hostileBullet(x,y,a,speed,style)` line 456 (cap 520); `aimedFan`/`radialPattern` line ~457. Enemy fire dispatch per archetype: line 479.

### 1.6 Sim loop — line 530
```
function loop(ts){if(!playing)return;sampleFrame(ts);try{var elapsed=Math.min(.12,Math.max(0,(ts-last)/1000||.016));last=ts;if(net.role==='guest'&&net.connected){sendGuestInput(false);if(!lastRender||ts-lastRender>=12){lastRender=ts;draw()}return}if(!paused){var step=1/60,steps=0;simAccumulator=Math.min(.12,simAccumulator+elapsed);while(simAccumulator>=step-.0001&&steps<8){update(step);simAccumulator-=step;steps++}}else{simAccumulator=0;readGamepad()}if(!lastRender||ts-lastRender>=12){lastRender=ts;draw()}}catch(err){handleFrameFault(err)}finally{if(playing&&!qaMode)requestAnimationFrame(loop)}}
```
Assessment: dt already clamped to 0.12 s; accumulator capped 0.12 s; fixed 1/60 steps, max 8/frame (no spiral of death — sheds time instead); `draw()` gated to ≥12 ms intervals (~83 fps cap); pause/visibilitychange (line 531) and `togglePause` (line 523) reset `simAccumulator`; `handleFrameFault` (line 529) resets accumulator and trims `enemyBullets`/`particles`/`debris` on crash. No interpolation — unnecessary at 60 Hz (one step per drawn frame). Minor caveat: on 120 Hz phones the sim still steps at 1/60 while draws cap at ~83 fps — fine, no stutter from that mismatch, but don't "fix" it by upping the draw rate.
**Hitch sources found:** (a) `activePilots().concat(wingmen)` allocates two throwaway arrays **per enemy bullet per sim step** (line 478) — with ~100 enemy bullets that's ~12k small allocs/sec; (b) `drawAircraftDamage` (line 498) allocates the 4×3 `spots` array literal **per enemy per frame**; (c) `sortieState`/`say()` toast timers trivial. §F gives the two safe hoists.

### 1.7 Particle system
- `burst(x,y,n,c)` (line 462): capped at 280 particles, `{x,y,vx,vy,life:.35–1.15,size:2–7,c}`; drawn as `fillRect` with `globalAlpha=p.life` (line 516); integrated in line 491 (`p.x+=p.vx*dt…; p.life-=dt`).
- `smokeColumns` (line 515/491): 6-circle stacked puffs, `r` grows, drift up 74 px/s, drawn `globalAlpha=min(.65,life/2)`.
- Crash trails (line 465 `updateCrashEntity`): per-crash `c.trail` puffs + flame particles — the template for battle-damage FX.
- **There is no idle smoke/fire emitter for live damaged aircraft** — §D adds one.

### 1.8 Enemy HP/damage handling
- Player bullets → enemy: line 488 `enemies.forEach(function(e){if(e.hp>0&&collide(b,e)){b.life=0;e.hp-=b.d;if(e.hp<=0){var worth=e.archetype==='triplane'?1200:e.archetype==='riser'?700:e.archetype==='green'?500:e.archetype==='red'?200:100;score+=worth;kills++;burst(e.x,e.y,e.archetype==='riser'?24:14);blip(120,.18,'square',.05);if(Math.random()<.18)spawnPower()}}});`
- Bomb splash: line 438 `e.hp-=6`. Blast powerup: line 489 sets `e.hp=0` (worth ternary duplicated: `score+=e.archetype==='triplane'?1200:…`).
- Removal: line 491 `enemies=enemies.filter(function(e){return e.hp>0&&e.ttl>0&&…})`.
- Damage visuals today: `drawAircraftDamage` (line 498) spots at ratio ≤.72, fire glow at ≤.42; `drawEnemy` (line 499) smoke puffs at ratio ≤**.55**; player `drawDamageTrail` (line 521) smoke ≤.72, fire ≤.40. §D re-tunes all to 50%/25%.

### Sprite asset facts
- `loadBankedSprites(prefix)` (line 198) loads `${prefix}-bank-left.png/-level.png/-damaged.png`? **No** — it loads only `-bank-left/-level/-bank-right`. The `-damaged` variant does **not** exist in the loader or in `assets/sprites/` (confirmed: no `*-damaged.png` files, and no `enemy-dri*` etc. files either — new archetype PNGs are an asset dependency, not yet delivered).
- `drawBlenderSprite` (line 198) guards `if(!im||!im.complete||!im.naturalWidth)return false` — missing sprites fail safe (enemy invisible, no crash). QA sprite evidence (`exerciseSpriteRendering`, line 557) would list them as missing — expected until assets land.
- `bankedSprite(set,bank)`: left if bank<−.18, right if >.18, else level.
- Player uses `drawPilot` (line 522) → procedural `plane()` (line 497) + `drawDamageTrail`; `spriteArt.player` banked sprites exist but are not the in-combat renderer. **Honest call per spec §D: no new player damaged sprites — re-tune the existing procedural trail to 50%/25% instead.**

---

## A. 10 NEW ARCHETYPES — transforms

### A1. Insert the stats table + Jasta index constants after ENEMY_LIVERIES (line 313)
Find (unique tail of the liveries line):
```
{name:'BLUE NOSE',base:'#5c635b',accent:'#335772',band:'#e8d9ad',pattern:'dazzle'}];
```
Replace with:
```
{name:'BLUE NOSE',base:'#5c635b',accent:'#335772',band:'#e8d9ad',pattern:'dazzle'},{name:'JASTA 11 · ALL RED',base:'#a8241a',accent:'#6e130d',band:'#e8d9ad',pattern:'streak'},{name:'JASTA 18',base:'#2f4d6e',accent:'#a8241a',band:'#e8d9ad',pattern:'dazzle'},{name:'JASTA 15',base:'#7e2a20',accent:'#2f4d6e',band:'#e8d9ad',pattern:'lozenge'},{name:'JASTA 27',base:'#c9a227',accent:'#23231f',band:'#ece0b7',pattern:'streak'},{name:'JASTA 36',base:'#33517c',accent:'#ece0b7',band:'#a8241a',pattern:'dazzle'}];
var JASTA11=6,JASTA18=7,JASTA15=8,JASTA27=9,JASTA36=10;
var ENEMY_ARCHETYPES={small:{hp:3,r:14,size:100,shoot:1.4,sprite:'scout',fire:'single',score:100},red:{hp:4,r:14,size:100,shoot:1.2,sprite:'fighter',fire:'single',score:200},green:{hp:12,r:24,size:100,shoot:1.75,sprite:'fighter',fire:'fan2',rear:true,score:500},riser:{hp:12,r:24,size:126,shoot:1.15,sprite:'bomber',fire:'fan5heavy',rear:true,score:700},triplane:{hp:18,r:18,size:104,shoot:.72,sprite:'triplane',fire:'fan3lead',elite:true,score:1200},dri:{hp:10,r:15,size:92,shoot:.68,sprite:'dri',fire:'fan2lead',elite:true,score:800,pathDur:5.6,freq:2.9,path:'swoop'},dvii:{hp:14,r:17,size:100,shoot:.95,sprite:'dvii',fire:'fan2',score:450,pathDur:6.6},dva:{hp:5,r:14,size:100,shoot:1.1,sprite:'dva',fire:'single',score:150,pathDur:5.4,freq:2.6},eiii:{hp:3,r:13,size:96,shoot:1.5,sprite:'eiii',fire:'single',score:80,pathDur:7.8,freq:1.7},pfalz:{hp:16,r:17,size:100,shoot:1.0,sprite:'pfalz',fire:'fan2',score:400,pathDur:6.2,path:'swoop'},gotha:{hp:40,r:30,size:160,shoot:1.5,sprite:'gotha',fire:'arc',score:1500,pathDur:8.6,freq:1.5},clii:{hp:12,r:16,size:104,shoot:1.3,sprite:'clii',fire:'single',score:350,pathDur:6.0,path:'swoop'},rumpler:{hp:9,r:16,size:110,shoot:1.4,sprite:'rumpler',fire:'rear',rear:true,score:300,pathDur:7.4},junkers:{hp:30,r:20,size:118,shoot:1.6,sprite:'junkers',fire:'single',score:900,pathDur:8.2,path:'swoop'},taube:{hp:2,r:13,size:104,shoot:2.2,sprite:'taube',fire:'single',score:60,pathDur:8.0,freq:1.6}};
function enemyWorth(a){var s=ENEMY_ARCHETYPES[a];return s?s.score:100}
```
Stat notes (doctrine-checked): player twin volley ≈ 2.0 dmg at level 1 (medium), so gotha (40 hp) ≈ 20 volleys / ~15 s sustained fire — a "boss-lite", fine for 1–2 per raid; junkers (30) ≈ 15 volleys. taube "unarmed-ish": handled in A5 (60% fire skip).

### A2. Sprite loader: add `-damaged` variant (line 198)
Find:
```
function loadBankedSprites(prefix){return{left:loadImage('assets/sprites/'+prefix+'-bank-left.png'),level:loadImage('assets/sprites/'+prefix+'-level.png'),right:loadImage('assets/sprites/'+prefix+'-bank-right.png')}}
```
Replace with:
```
function loadBankedSprites(prefix){return{left:loadImage('assets/sprites/'+prefix+'-bank-left.png'),level:loadImage('assets/sprites/'+prefix+'-level.png'),right:loadImage('assets/sprites/'+prefix+'-bank-right.png'),damaged:loadImage('assets/sprites/'+prefix+'-damaged.png')}}
```
Safe for existing sets: `drawBlenderSprite` ignores missing images (no `-damaged.png` exists yet — 404s in console only).

### A3. Register the 10 sprite sets (line 198, same statement as above)
Find:
```
var spriteArt={aircraft:{triplane:loadBankedSprites('enemy-triplane'),scout:loadBankedSprites('enemy-scout'),fighter:loadBankedSprites('enemy-fighter'),bomber:loadBankedSprites('enemy-bomber')},
```
Replace with:
```
var spriteArt={aircraft:{triplane:loadBankedSprites('enemy-triplane'),scout:loadBankedSprites('enemy-scout'),fighter:loadBankedSprites('enemy-fighter'),bomber:loadBankedSprites('enemy-bomber'),dri:loadBankedSprites('enemy-dri'),dvii:loadBankedSprites('enemy-dvii'),dva:loadBankedSprites('enemy-dva'),eiii:loadBankedSprites('enemy-eiii'),pfalz:loadBankedSprites('enemy-pfalz'),gotha:loadBankedSprites('enemy-gotha'),clii:loadBankedSprites('enemy-clii'),rumpler:loadBankedSprites('enemy-rumpler'),junkers:loadBankedSprites('enemy-junkers'),taube:loadBankedSprites('enemy-taube')},
```
Asset dependency: `assets/sprites/enemy-{dri,dvii,dva,eiii,pfalz,gotha,clii,rumpler,junkers,taube}-{bank-left,level,bank-right,damaged}.png` (40 PNGs) are **not in the repo** — code degrades to invisible-but-harmless enemies until they land (see Risk 1).

### A4. spawnEnemy() reads the table (line 442)
Find:
```
var livery=opts.livery===undefined?Math.floor(Math.random()*ENEMY_LIVERIES.length):opts.livery,squad=opts.squad||++squadronSerial,elite=kind==='triplane'||opts.elite,heavy=kind==='green'||kind==='riser',e={id:++entityId,x:-90,y:-90,vx:0,vy:0,r:elite?18:heavy?24:14,hp:elite?18:heavy?12:kind==='red'?4:3,max:elite?18:heavy?12:kind==='red'?4:3,phase:Math.random()*6.28,shoot:elite?.52:heavy?1.12:.9+Math.random()*.5,archetype:kind,ttl:99,route:'parametric',bank:0,livery:livery,squad:squad,elite:elite,rearGunner:heavy,pathState:{name:opts.path||'sine',t:0,delay:opts.delay||0,duration:opts.pathDuration||(elite?5.8:7.2),config:opts.pathConfig||{mirror:Math.random()<.5,phase:Math.random()*6.28,frequency:2.2,center:.5}}}
```
Replace with:
```
var livery=opts.livery===undefined?Math.floor(Math.random()*ENEMY_LIVERIES.length):opts.livery,squad=opts.squad||++squadronSerial,st=ENEMY_ARCHETYPES[kind]||ENEMY_ARCHETYPES.small,elite=st.elite||opts.elite||kind==='triplane',e={id:++entityId,x:-90,y:-90,vx:0,vy:0,r:st.r,hp:st.hp,max:st.hp,phase:Math.random()*6.28,shoot:(st.shoot||1)+Math.random()*.4,archetype:kind,ttl:99,route:'parametric',bank:0,livery:livery,squad:squad,elite:elite,rearGunner:!!st.rear,pathState:{name:opts.path||st.path||'sine',t:0,delay:opts.delay||0,duration:opts.pathDuration||st.pathDur||(elite?5.8:7.2),config:opts.pathConfig||{mirror:Math.random()<.5,phase:Math.random()*6.28,frequency:st.freq||2.2,center:.5}}}
```

### A5. Enemy fire dispatch for new patterns + taube skip (line 479)
Find:
```
}else hostileBullet(e.x,e.y,a,164,'tracer');e.shoot=(e.archetype==='triplane'?.72:e.archetype==='riser'?1.15:e.archetype==='green'?1.75:1.4+Math.random()*.8)*difficultyProfile().enemyFire}
```
Replace with:
```
}else enemyFirePattern(e,target,a);e.shoot=((ENEMY_ARCHETYPES[e.archetype]||{}).shoot||1.4+Math.random()*.8)*difficultyProfile().enemyFire}
```
Then insert the new function right after `hostileBullet` (find the line `function aimedFan(x,y,target,count,spread,speed,style){` and prepend before it):
```
function enemyFirePattern(e,target,a){var st=ENEMY_ARCHETYPES[e.archetype]||ENEMY_ARCHETYPES.small,f=st.fire||'single';if(f==='fan5heavy')aimedFan(e.x,e.y,target,5,.72,178,'heavy');else if(f==='fan2')aimedFan(e.x,e.y,target,2,.2,152,'tracer');else if(f==='fan3lead'){var l0={x:target.x+target.vx*.34,y:target.y+target.vy*.34};aimedFan(e.x,e.y,l0,3,.16,225,'heavy')}else if(f==='fan2lead'){var l1={x:target.x+target.vx*.3,y:target.y+target.vy*.3};aimedFan(e.x,e.y,l1,2,.14,215,'heavy')}else if(f==='rear')aimedFan(e.x,e.y,target,2,.3,150,'gold');else if(f==='arc'){aimedFan(e.x,e.y,target,4,1.6,140,'tracer');aimedFan(e.x,e.y,target,2,.4,120,'heavy')}else{if(e.archetype==='taube'&&Math.random()<.6)return;hostileBullet(e.x,e.y,a,164,'tracer')}}
```
Existing `riser`/`green`/`triplane` branches above the final `else` are untouched — new archetypes fall through to `enemyFirePattern`.

### A6. Score worth via table (lines 488, 489 — two sites, disambiguate by prefix)
Find (line 488, has `var worth=`):
```
var worth=e.archetype==='triplane'?1200:e.archetype==='riser'?700:e.archetype==='green'?500:e.archetype==='red'?200:100;
```
Replace with:
```
var worth=enemyWorth(e.archetype);
```
Find (line 489, has `score+=`):
```
score+=e.archetype==='triplane'?1200:e.archetype==='riser'?700:e.archetype==='green'?500:e.archetype==='red'?200:100;
```
Replace with:
```
score+=enemyWorth(e.archetype);
```

### A7. drawEnemy() uses the table + damaged-sprite swap (line 499)
Find:
```
function drawEnemy(e){if(e.pathHidden)return;var kind=e.archetype==='riser'?'bomber':e.archetype==='triplane'?'triplane':e.archetype==='green'?'fighter':e.archetype==='red'?'fighter':'scout',set=spriteArt.aircraft[kind],im=bankedSprite(set,e.bank||0),size=kind==='bomber'?126:kind==='triplane'?104:100,heading=e.pathHeading===undefined?Math.atan2(e.vy||1,e.vx||0):e.pathHeading,rot=heading+Math.PI/2;drawBlenderSprite(im,e.x,e.y,size,rot,1);var damageScale=kind==='bomber'?1.72:kind==='fighter'?1.18:1.02;
```
Replace with:
```
function drawEnemy(e){if(e.pathHidden)return;var st=ENEMY_ARCHETYPES[e.archetype]||ENEMY_ARCHETYPES.small,set=spriteArt.aircraft[st.sprite],im=bankedSprite(set,e.bank||0);if(e.hp/e.max<=.25&&set.damaged)im=set.damaged;var size=st.size,heading=e.pathHeading===undefined?Math.atan2(e.vy||1,e.vx||0):e.pathHeading,rot=heading+Math.PI/2;drawBlenderSprite(im,e.x,e.y,size,rot,1);var damageScale=st.size/100;
```
(ris`er`/bomber size 126 preserved via table.)

### A8. QA seen-map extension (lines 177 and 433 — apply at BOTH sites)
Find (appears twice; edit each):
```
seen:{small:false,green:false,red:false,riser:false,triplane:false}
```
Replace with:
```
seen:{small:false,green:false,red:false,riser:false,triplane:false,dri:false,dvii:false,dva:false,eiii:false,pfalz:false,gotha:false,clii:false,rumpler:false,junkers:false,taube:false}
```
(`addEnemy`, line 441, already does `qa.seen[e.archetype]=true` generically.)

---

## B. JASTA SQUADRON LIVERY SYSTEM — transforms

B1. The 5 entries + `JASTA11…JASTA36` constants are added in §A1 (indexes 6–10).

B2. Wave announcement: find (unique, end of `queueWave`, line 321):
```
5.8:6.3+(i%3)*.55});}return true}
```
Replace with:
```
5.8:6.3+(i%3)*.55});}if(opts.label)say(opts.label);return true}
```
(`say()` = 1.2 s toast, line 379 — the in-wave announcement channel.)

B3. Elite wave type override (line 321, same statement): find
```
var type=elite?'triplane':(opts.type||['small','green','red','riser'][wave%4])
```
Replace with:
```
var type=elite?(opts.type||'triplane'):(opts.type||['small','green','red','riser'][wave%4])
```
(This lets elite waves be `dri` aces instead of always `triplane`; §C passes `type:plan.ace`.)

B4. Livery semantics for Jasta waves: pass `livery:JASTA11` etc. in the `queueWave` opts (§C). Note: planes within the wave still shift `(livery+i%2)%11` — so a Jasta wave alternates between the squadron livery (index 6) and index 7 (Jasta 18). To keep a Jasta formation visually uniform, the spec's §C spawns Jasta waves with `spacing:.1` and accepts the ±1 alternation OR the builder may pass the same livery for both; simplest: Jasta waves use `livery:JASTA11` and the i%2 shift produces 6/7 — acceptable ("Jasta 11 with Jasta 18 flights mixed") — OR add an opts flag. **Decision: keep the shift; document as "squadron mixed flights".** No extra code.

---

## C. WAVE COMPOSITION WEAVING (32 sorties) — transforms

### C1. Insert SORTIE_ROSTER after the JASTA constants (end of §A1 block)
```js
var SORTIE_ROSTER=[
{pool:['taube','eiii','small']},
{pool:['taube','eiii','small','clii']},
{pool:['eiii','taube','small']},
{pool:['taube','eiii','clii','small']},
{pool:['eiii','small','clii']},
{pool:['small','eiii','clii','red']},
{pool:['small','clii','red','eiii']},
{pool:['clii','red','small','green']},
{pool:['rumpler','small','red','green']},
{pool:['rumpler','dva','green','red']},
{pool:['dva','pfalz','rumpler','green']},
{pool:['pfalz','dva','green','rumpler']},
{pool:['rumpler','dva','pfalz','green']},
{pool:['dva','pfalz','green','red']},
{pool:['pfalz','junkers','dva','green']},
{pool:['junkers','pfalz','rumpler','green']},
{pool:['dva','pfalz','junkers','riser']},
{pool:['pfalz','dva','rumpler','junkers']},
{pool:['junkers','pfalz','dva','rumpler']},
{pool:['pfalz','dva','green','rumpler']},
{pool:['dvii','pfalz','dva','green'],ace:'dri',jasta:[{type:'dvii',livery:JASTA36,label:'JASTA 36 · BLUE'}]},
{pool:['dvii','dri','pfalz','riser'],ace:'dri',gotha:true},
{pool:['dvii','dri','pfalz'],ace:'dri',jasta:[{type:'dvii',livery:JASTA18,label:'JASTA 18 · BLUE FUSELAGE · RED NOSE'}]},
{pool:['dri','dvii','riser'],ace:'dri',gotha:true,jasta:[{type:'dri',livery:JASTA11,label:'JASTA 11 · ALL RED'}]},
{pool:['dvii','dri','pfalz','riser'],ace:'dri',jasta:[{type:'dvii',livery:JASTA15,label:'JASTA 15 · RED AND BLUE'}]},
{pool:['dri','dvii','riser'],ace:'dri',gotha:true,jasta:[{type:'dri',livery:JASTA11,label:'JASTA 11 · ALL RED'}]},
{pool:['dvii','dri','pfalz'],ace:'dri',jasta:[{type:'dvii',livery:JASTA27,label:'JASTA 27 · YELLOW AND BLACK'}]},
{pool:['dri','dvii','riser'],ace:'dri',gotha:true},
{pool:['dvii','dri','pfalz','riser'],ace:'dri',jasta:[{type:'dvii',livery:JASTA11,label:'JASTA 11 · ALL RED'},{type:'dri',livery:JASTA36,label:'JASTA 36 · BLUE'}]},
{pool:['dri','dvii','riser'],ace:'dri',gotha:true,jasta:[{type:'dri',livery:JASTA11,label:'JASTA 11 · ALL RED'}]},
{pool:['dvii','dri','riser','pfalz'],ace:'dri',jasta:[{type:'dvii',livery:JASTA18,label:'JASTA 18 · BLUE FUSELAGE · RED NOSE'},{type:'dri',livery:JASTA11,label:'JASTA 11 · ALL RED'}]},
{pool:['dri','dvii','riser'],ace:'dri',gotha:true,jasta:[{type:'dri',livery:JASTA11,label:'JASTA 11 · ALL RED'},{type:'dvii',livery:JASTA15,label:'JASTA 15 · RED AND BLUE'}]}];
```
Weaving logic: early (idx 0–7) = taube/eiii/clii + scouts (taube only 0–3); mid (8–19) = rumpler (rear gunner), dva, pfalz, junkers trench strafers; late (20–31) = dvii squadrons, dri aces (`ace:'dri'` → elite waves become Dr.I), gotha raids, Jasta formations of 5–7.

### C2. Rewrite spawnFormation() (line 443)
Find:
```
function spawnFormation(){if(WaveManager.queue.length||enemyRoom()<5||WaveManager.wave>=WaveManager.maxWaves)return false;var next=WaveManager.wave+1,elite=next%4===0&&next-WaveManager.lastElite>=3&&!enemies.some(function(e){return e.elite&&e.hp>0});return WaveManager.queueWave({elite:elite,size:2+Math.floor(progress.selected/8)+next%2,pattern:WaveManager.patterns[next%WaveManager.patterns.length]})}
```
Replace with:
```
function spawnFormation(){if(WaveManager.queue.length||enemyRoom()<5||WaveManager.wave>=WaveManager.maxWaves)return false;var next=WaveManager.wave+1,sel=progress.selected,plan=SORTIE_ROSTER[sel]||SORTIE_ROSTER[0],pool=plan.pool||['small'],elite=next%4===0&&next-WaveManager.lastElite>=3&&!enemies.some(function(e){return e.elite&&e.hp>0});if(plan.gotha&&next%3===0&&enemyRoom()>=7){WaveManager.queueWave({type:'gotha',size:1+(next%2),path:'sine',pattern:'beam',spacing:.4,livery:next%6});return WaveManager.queueWave({type:'dvii',size:4,path:'swoop',pattern:'vee',spacing:.31,livery:next%6,label:'GOTHA RAID · ESCORT INBOUND'})}if(plan.jasta&&next%2===0){var j=plan.jasta[((next/2)|0)%plan.jasta.length];return WaveManager.queueWave({type:j.type,size:5+(next%3),path:'loop',pattern:'vee',spacing:.1,livery:j.livery,label:j.label})}return WaveManager.queueWave({elite:elite,type:elite?(plan.ace||'dri'):pool[next%pool.length],size:2+Math.floor(sel/8)+next%2,pattern:WaveManager.patterns[next%WaveManager.patterns.length]})}
```

### C3. Fix the wave-size clamp for the 2–3 → 5–7 ramp (line 321)
Find:
```
size=elite?1:Math.max(4,Math.min(6,opts.size||4+wave%3))
```
Replace with:
```
size=elite?1:Math.max(2,Math.min(7,opts.size||4+wave%3))
```
(Previously the `Math.max(4,…)` silently overrode `spawnFormation`'s early 2–3 size. 1942 pacing cadence itself — line 476 `(5+Math.random()*5)/difficultyProfile().wave` — is unchanged.)

---

## D. BATTLE DAMAGE — transforms

### D1. Enemy damage emitter (new function; insert before `function spawnEnemy` at line 442)
```js
function enemyDamageFx(e,dt){var ratio=e.hp/e.max;if(ratio>=.5||ratio<=0||e.pathHidden)return;e.dmgT=(e.dmgT||0)-dt;if(e.dmgT>0)return;var fire=ratio<.25;e.dmgT=fire?.05:.12;if(particles.length>=280)return;particles.push({x:e.x+(Math.random()-.5)*14,y:e.y+10,vx:(Math.random()-.5)*30,vy:-40-Math.random()*60,life:fire?.7+Math.random()*.5:1.1+Math.random()*.7,size:fire?6+Math.random()*8:8+Math.random()*10,c:fire?(Math.random()<.5?'#ff8b2d':'#2a2925'):(Math.random()<.5?'#3a382f':'#57503f')})}
```
Wire it in (line 479): find
```
*1.4+Math.random()*.8)*difficultyProfile().enemyFire}activePilots().some(function(p){if(p.hp>0&&collide(p,e)){e.hp=0;hitPilot(p);return true}return false})
```
Replace with:
```
*1.4+Math.random()*.8)*difficultyProfile().enemyFire}enemyDamageFx(e,dt);activePilots().some(function(p){if(p.hp>0&&collide(p,e)){e.hp=0;hitPilot(p);return true}return false})
```
(Note: after §A5 the shoot-reset line changed form — match on the tail `*difficultyProfile().enemyFire}activePilots().some(function(p){if(p.hp>0&&collide(p,e)){e.hp=0;hitPilot(p);return true}return false})`, which is unique either way.)

### D2. Re-tune enemy smoke threshold 55% → 50%, add fire glow ≤25% (line 499)
Find:
```
if(e.hp/e.max<=.55){var v=(e.id||1)%4;
```
Replace with:
```
if(e.hp/e.max<=.5){var v=(e.id||1)%4;
```
Find (unique tail of drawEnemy):
```
q*2,0,6.283);ctx.fill()}ctx.restore()}}
```
Replace with:
```
q*2,0,6.283);ctx.fill()}ctx.restore()}if(e.hp/e.max<=.25){ctx.save();ctx.globalCompositeOperation='lighter';ctx.globalAlpha=.85;ctx.fillStyle='#ff7b24';ctx.beginPath();ctx.ellipse(e.x,e.y+16,5,11,Math.sin(time*8+(e.id||0))*.14,0,6.283);ctx.fill();ctx.fillStyle='#ffd173';ctx.beginPath();ctx.ellipse(e.x,e.y+12,2.5,6,0,0,6.283);ctx.fill();ctx.restore()}}
```
Damaged-sprite swap ≤25% is in §A7. `drawAircraftDamage` (line 498) already draws spots ≤.72 / heavy ≤.42 — leave as-is (procedural damage sits under the new FX; changing it is optional polish).

### D3. Player SPAD: re-tune existing procedural trail (line 521) — honest call: NO new player sprites
Find:
```
function drawDamageTrail(p,scale,x,y){var max=p.maxHp||5,ratio=p.hp/max;if(ratio>.72||p.hp<=0)return;var heavy=ratio<=.4,
```
Replace with:
```
function drawDamageTrail(p,scale,x,y){var max=p.maxHp||5,ratio=p.hp/max;if(ratio>.5||p.hp<=0)return;var heavy=ratio<=.25,
```
Player damaged sprites are future work — the trail already gives smoke ≤50% / fire ≤25%, which satisfies the spec's intent without inventing assets. (`drawAircraftDamage(p,…)` at line 522 unchanged.)

---

## E. LUMINOUS TRACERS — transforms (line 516)

### E1. Player bullets — additive glow, near-white core, gold/green hue coding
Find:
```
bullets.forEach(function(b){ctx.strokeStyle=b.owner>2?'#b8f2ec':'#fff1a4';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(b.x,b.y);ctx.lineTo(b.x-b.vx*.018,b.y-b.vy*.018);ctx.stroke()});
```
Replace with:
```
bullets.forEach(function(b){var hue=b.owner===2?'#7ef29a':b.owner>2?'#8ff2e8':'#ffd76a';ctx.save();ctx.globalCompositeOperation='lighter';ctx.shadowBlur=13;ctx.shadowColor=hue;ctx.strokeStyle=hue;ctx.lineWidth=3;ctx.beginPath();ctx.moveTo(b.x,b.y);ctx.lineTo(b.x-b.vx*.022,b.y-b.vy*.022);ctx.stroke();ctx.shadowBlur=0;ctx.strokeStyle='#fffdf4';ctx.lineWidth=1.2;ctx.beginPath();ctx.moveTo(b.x,b.y);ctx.lineTo(b.x-b.vx*.016,b.y-b.vy*.016);ctx.stroke();ctx.restore()});
```
Hue coding: P1 warm gold `#ffd76a`, P2 green `#7ef29a`, wingmen teal `#8ff2e8`. Near-white `#fffdf4` core keeps the tracer readable against bright terrain (the colored halo washes out on bright ground, the white core doesn't).

### E2. Enemy bullets — stronger glow + bright core
Find:
```
enemyBullets.forEach(function(b){ctx.save();ctx.globalCompositeOperation='lighter';ctx.shadowBlur=10;ctx.shadowColor=b.style==='gold'?'#ffd76a':'#ff5a35';ctx.fillStyle=b.style==='gold'?'#ffe88c':b.style==='heavy'?'#ffddd0':'#ff754b';ctx.beginPath();ctx.arc(b.x,b.y,b.r,0,6.28);ctx.fill();ctx.strokeStyle='rgba(255,226,175,.7)';ctx.lineWidth=1.2;ctx.beginPath();ctx.moveTo(b.x-b.vx*.025,b.y-b.vy*.025);ctx.lineTo(b.x,b.y);ctx.stroke();ctx.restore()});
```
Replace with:
```
enemyBullets.forEach(function(b){ctx.save();ctx.globalCompositeOperation='lighter';ctx.shadowBlur=18;ctx.shadowColor=b.style==='gold'?'#ffd76a':'#ff5a35';ctx.fillStyle=b.style==='gold'?'#ffe88c':b.style==='heavy'?'#ffddd0':'#ff754b';ctx.beginPath();ctx.arc(b.x,b.y,b.r,0,6.28);ctx.fill();ctx.shadowBlur=0;ctx.fillStyle='rgba(255,255,250,.95)';ctx.beginPath();ctx.arc(b.x,b.y,Math.max(1,b.r*.45),0,6.28);ctx.fill();ctx.strokeStyle='rgba(255,226,175,.75)';ctx.lineWidth=1.4;ctx.beginPath();ctx.moveTo(b.x-b.vx*.025,b.y-b.vy*.025);ctx.lineTo(b.x,b.y);ctx.stroke();ctx.restore()});
```
Enemy hues stay red/orange (`#ff5a35` glow, `#ff754b` body, gold `#ffd76a` for rear-observer/gold styles) — visually distinct from player gold-green at a glance. Perf note: `shadowBlur:18` on up to 520 enemy bullets + 13 on 300 player bullets is the heaviest new GPU cost — if a 120 Hz phone drops frames, first dial these down, don't touch the sim.

---

## F. SMOOTHNESS — transforms (line 475–479 region)

### F1. Hoist the pilot-target array out of the per-bullet loop (verified allocation hotspot)
Find:
```
bullets.forEach(function(b){b.x+=b.vx*dt;b.y+=b.vy*dt;b.life-=dt});enemyBullets.forEach(function(b){b.x+=b.vx*dt;b.y+=b.vy*dt;b.life-=dt;activePilots().concat(wingmen).some(function(p){if(p.hp<=0)return false;
```
Replace with:
```
bullets.forEach(function(b){b.x+=b.vx*dt;b.y+=b.vy*dt;b.life-=dt});var pilotTargets=activePilots().concat(wingmen);enemyBullets.forEach(function(b){b.x+=b.vx*dt;b.y+=b.vy*dt;b.life-=dt;pilotTargets.some(function(p){if(p.hp<=0)return false;
```
(One allocation per sim step instead of per bullet per step. Behavior identical: `pilotTargets` is read-only in the loop.)

### F2. (Optional, safe) Hoist the damage-spot arrays in drawAircraftDamage (line 498)
Find:
```
var v=(o.damageVariant===undefined?(o.id||1)%4:o.damageVariant)%4,heavy=ratio<=.42,spots=[[[-16,-4],[10,3],[1,-17]],[[17,-2],[-8,10],[-1,-19]],[[-19,5],[18,7],[4,-9]],[[-11,-13],[12,-11],[0,13]]][v];
```
Replace with:
```
var v=(o.damageVariant===undefined?(o.id||1)%4:o.damageVariant)%4,heavy=ratio<=.42,spots=DAMAGE_SPOTS[v];
```
And insert before `function drawAircraftDamage`:
```
var DAMAGE_SPOTS=[[[-16,-4],[10,3],[1,-17]],[[17,-2],[-8,10],[-1,-19]],[[-19,5],[18,7],[4,-9]],[[-11,-13],[12,-11],[0,13]]];
```

### F3. Verified-no-change items (do NOT touch)
- `loop()` (line 530): dt clamped `.12`, accumulator capped `.12`, fixed `1/60` steps, `steps<8` — already spiral-of-death-safe. No change.
- Draw gate `ts-lastRender>=12` — adequate; don't raise the draw rate on 120 Hz phones (GPU cost).
- `handleFrameFault` (line 529) — keep the array-trim recovery.
- Bullet caps (`hostileBullet` 520, `burst` 280, player 300) — keep; `enemyDamageFx` respects the 280 cap.

---

## G. Structural risks

1. **Asset dependency (biggest):** none of the 40 new `enemy-{dri,…,taube}-{bank-left,level,bank-right,damaged}.png` files exist in `assets/sprites/`. Code is crash-safe (`drawBlenderSprite` returns false on missing images) but enemies will be **invisible** until art lands. Also `*-damaged.png` doesn't exist for ANY aircraft yet. Recommend: land art before enabling, or temporarily point new archetypes at existing sprites (e.g. `sprite:'fighter'`) — the table makes this a one-field change.
2. **Minified single-line statements:** every find block above is a substring of a very long line. `artifact.edit` matches must be character-exact; the two `worth` ternaries (lines 488/489) and the two `seen:{…}` maps (lines 177/433) are disambiguated by prefix/site as noted — edit both `seen` sites.
3. **`e.returning` is dead** (line 479): the green archetype's gold rear-gunner shot never fires today. The new `rumpler` `'rear'` pattern fires gold at the player regardless — intended, and documented as the honest approximation of a rear observer.
4. **Enemy cap:** `MAX_ACTIVE_ENEMIES=10`; Jasta waves of 5–7 + in-flight enemies can hit the cap — `WaveManager.update` already drains only while `enemyRoom()>0`, so waves queue patiently. No change needed.
5. **Co-op/net:** `applyNetSnapshot` (line 420) wholesale-replaces enemy objects; new fields (`dmgT`) don't sync — harmless (FX-only, re-derives).
6. **`campaign[].composition` is flavor-only** (never read) — §C's `SORTIE_ROSTER` is the first real per-sortie air roster. Historical `force:` strings (e.g. "5 FOKKERS") will now disagree with spawned types on some sorties — acceptable arcade license, or update strings later.
7. **Livery shift in Jasta waves:** `(livery+i%2)%11` alternates JASTA11↔JASTA18 etc. within a formation — documented as mixed squadron flights; uniform look needs an extra opts flag (not specced).
8. **shadowBlur cost:** E1/E2 raise per-bullet GPU cost. If mobile frames drop, reduce blur first — never the sim rate.

## H. Couldn't verify

- `samplePath` z/altitude semantics for `loop`/`sine`/`swoop` (gotha "high altitude", clii/junkers "low trench strafing" are approximated via `path` + `pathDur` only — true altitude layering unconfirmed).
- In-browser render check of any transform (no live browser in this session) — all transforms are code-review-level; the builder should run `AceQA.runSpriteEvidence` and eyeball one sortie per era band (S1, S10, S20, S32).
- Whether `say()` toasts collide with Jasta labels when a cue fires the same frame (both write `toast.textContent` — last write wins; cosmetic only).
- Exact pixel look of new sprites (assets pending) — sizes in the table assume roughly 1:1 with existing 100px aircraft art.
