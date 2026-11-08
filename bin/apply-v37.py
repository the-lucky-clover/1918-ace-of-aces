#!/usr/bin/env python3
"""Apply the v37 explosion edits to 1918-ace-of-aces.html.
Every replacement asserts its anchor occurs exactly once.
Usage: python3 /tmp/apply-v37.py (run from the repo root; edits in place)."""
import sys

P = '1918-ace-of-aces.html'
h = open(P, encoding='utf-8').read()

def rep(old, new, tag):
    global h
    n = h.count(old)
    assert n == 1, '%s: anchor occurs %d times' % (tag, n)
    h = h.replace(old, new)
    print('ok', tag)

# 1. state: explosions array in the master var declaration.
rep("bombBlasts=[],smokeColumns=[],ambientFires=[]",
    "bombBlasts=[],smokeColumns=[],explosions=[],ambientFires=[]", "state decl")

# 2. v37 art: load the 8 explosion frames after the v36 plates.
rep("var v36Art={fireglow:loadImage('assets/sprites/v36/v36-fireglow.png'),ember:loadImage('assets/sprites/v36/v36-ember.png'),smoke2:loadImage('assets/sprites/v36/v36-smoke2.png'),smokedark:loadImage('assets/sprites/v36/v36-smokedark.png'),cloud:loadImage('assets/sprites/v36/v36-cloud.png')};",
    "var v36Art={fireglow:loadImage('assets/sprites/v36/v36-fireglow.png'),ember:loadImage('assets/sprites/v36/v36-ember.png'),smoke2:loadImage('assets/sprites/v36/v36-smoke2.png'),smokedark:loadImage('assets/sprites/v36/v36-smokedark.png'),cloud:loadImage('assets/sprites/v36/v36-cloud.png')};\n/* v37 photorealistic kill explosions — 8 raster frames built by\n   bin/build-v37-explosions.py from the v34 fire/flash/smoke sheets and the\n   v36 smoke/ember plates (all cut from the one true aerial photograph).\n   Flash -> fireball -> smoke -> embers. No drawn fireball, no vector shape,\n   no generated pixel: the visible RGB is 100% photographic. */\nvar v37Art={explosion:[loadImage('assets/sprites/v37/v37-explosion-0.png'),loadImage('assets/sprites/v37/v37-explosion-1.png'),loadImage('assets/sprites/v37/v37-explosion-2.png'),loadImage('assets/sprites/v37/v37-explosion-3.png'),loadImage('assets/sprites/v37/v37-explosion-4.png'),loadImage('assets/sprites/v37/v37-explosion-5.png'),loadImage('assets/sprites/v37/v37-explosion-6.png'),loadImage('assets/sprites/v37/v37-explosion-7.png')]};",
    "v37Art load")

# 3. the explosion system, right after drawSmokeColumn.
rep("else drawFxSheet(fxArt.smoke,Math.floor(time*3)%4,c.x,c.y-c.r*0.6,c.r*4,0,a)}",
    """else drawFxSheet(fxArt.smoke,Math.floor(time*3)%4,c.x,c.y-c.r*0.6,c.r*4,0,a)}
/* v37 kill explosions — a destroyed enemy plays the 8 photographic frames
   over ~0.55-0.9s: white-hot flash, orange fireball blooming, dark smoke
   rolling, embers falling and fading. Frames are pre-rendered plates; each
   explosion instance just plays the sequence. Max 8 at once, max radius
   capped (ghost 140) so a kill never fills the screen. Fire frames (0-3)
   draw additive so they glow; smoke frames (4-7) draw normal so the dark
   smoke reads. Explosions are drawn BEFORE the bullets and pilots in
   draw(), so a kill never hides an incoming round or the player's SPAD. */
var EXPLOSION_MAX=8;
var EXPLOSION_SIZE={small:{r:44,dur:0.55},medium:{r:64,dur:0.65},large:{r:92,dur:0.75},boss:{r:120,dur:0.8},ghost:{r:140,dur:0.9}};
function explosionSizeFor(e){if(e.heavy||e.archetype==='gotha'||e.archetype==='bomber'||(e.r||0)>=30)return 'large';if((e.r||0)>=20||e.archetype==='triplane'||e.archetype==='riser')return 'medium';return 'small'}
function spawnExplosion(x,y,size){if(explosions.length>=EXPLOSION_MAX)return;var s=EXPLOSION_SIZE[size]||EXPLOSION_SIZE.small;explosions.push({x:x,y:y,t:0,dur:s.dur,r:s.r,size:size});if(smokeColumns.length<26){smokeColumns.push({x:x,y:y-6,life:3.4,r:10,sheet:'dark',phase:Math.random()*6.28});smokeColumns.push({x:x+(Math.random()-.5)*24,y:y-14,life:2.6,r:8,sheet:'dark',phase:Math.random()*6.28})}}
function updateExplosions(dt){for(var i=0;i<explosions.length;i++)explosions[i].t+=dt;explosions=explosions.filter(function(e){return e.t<e.dur})}
function drawExplosion(e){var u=Math.max(0,Math.min(1,e.t/e.dur)),fi=Math.min(7,Math.floor(u*8)),grow=0.55+0.5*Math.min(1,u*2.2),alpha=u<0.7?1:1-(u-0.7)/0.3,size=e.r*2*grow;if(fi<=3){ctx.save();ctx.globalCompositeOperation='lighter';drawFx(v37Art.explosion[fi],e.x,e.y,size,0,Math.min(1,alpha*0.9));ctx.restore()}else drawFx(v37Art.explosion[fi],e.x,e.y,size,0,alpha*0.85)}""",
    "explosion system")

# 4. reset(): clear explosions on a fresh sortie.
rep("bombBlasts=[];smokeColumns=[];wrecks=[];",
    "bombBlasts=[];smokeColumns=[];explosions=[];wrecks=[];", "reset")

# 5. clearProofWorld(): clear explosions for the sprite-evidence scenes.
rep("particles=[];smokeColumns=[];ambientFires=[];",
    "particles=[];smokeColumns=[];explosions=[];ambientFires=[];", "clearProofWorld")

# 6. update(): advance explosions with the rest of the world.
rep("particles.forEach(function(p){if(p.grav)p.vy+=p.grav*dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.vx*=.96;p.vy*=.96;p.life-=dt});particles=particles.filter(function(p){return p.life>0});updateHud();sendNetSnapshot()}",
    "updateExplosions(dt);particles.forEach(function(p){if(p.grav)p.vy+=p.grav*dt;p.x+=p.vx*dt;p.y+=p.vy*dt;p.vx*=.96;p.vy*=.96;p.life-=dt});particles=particles.filter(function(p){return p.life>0});updateHud();sendNetSnapshot()}",
    "update explosions")

# 7. air-enemy kill hook: onEnemyDestroyed runs exactly once per kill.
rep("function onEnemyDestroyed(e){if(e.crashSiteDone)return;e.crashSiteDone=true;airKills++;",
    "function onEnemyDestroyed(e){if(e.crashSiteDone)return;e.crashSiteDone=true;airKills++;spawnExplosion(e.x,e.y,explosionSizeFor(e));",
    "air kill hook")

# 8. boss death: the big one — ghost gets the biggest (capped) explosion.
rep("burst(bx,by,86,'#e46b33');blip(55,1,'sawtooth',.16);",
    "burst(bx,by,86,'#e46b33');spawnExplosion(bx,by,completedStage===31?'ghost':'boss');blip(55,1,'sawtooth',.16);",
    "boss death")

# 9. boss death sequence: a medium explosion at each timed burst mark.
rep("burst(d.x+(Math.random()-.5)*120,d.y+(Math.random()-.5)*50,34,'#f39738');burst(d.x+(Math.random()-.5)*60,d.y+(Math.random()-.5)*30,18,'#ffd06a');shake=Math.max(shake,.5)",
    "burst(d.x+(Math.random()-.5)*120,d.y+(Math.random()-.5)*50,34,'#f39738');burst(d.x+(Math.random()-.5)*60,d.y+(Math.random()-.5)*30,18,'#ffd06a');spawnExplosion(d.x+(Math.random()-.5)*80,d.y+(Math.random()-.5)*40,'medium');shake=Math.max(shake,.5)",
    "boss death marks")

# 10. ground kill: balloons and fuel dumps go up in a medium explosion.
rep("burst(g.x,g.y,g.type==='balloon'||g.type==='fuel'?32:18,g.type==='balloon'||g.type==='fuel'?'#f39738':'#6c5b3d');if(g.type==='fuel'||g.type==='balloon')releaseGas(g.x,g.y);gwGroundKill(g)}",
    "burst(g.x,g.y,g.type==='balloon'||g.type==='fuel'?32:18,g.type==='balloon'||g.type==='fuel'?'#f39738':'#6c5b3d');if(g.type==='balloon'||g.type==='fuel')spawnExplosion(g.x,g.y,'medium');if(g.type==='fuel'||g.type==='balloon')releaseGas(g.x,g.y);gwGroundKill(g)}",
    "ground balloon/fuel kill")

# 11. balloon ignition death: the burning balloon bursts in a medium explosion.
rep("burst(g.x,g.y,52,'#ff7726');shake=.9;flash=.3",
    "burst(g.x,g.y,52,'#ff7726');spawnExplosion(g.x,g.y,'medium');shake=.9;flash=.3",
    "balloon ignition death")

# 12. draw(): explosions render after the smoke columns and ambient clouds,
#     BEFORE the bullets and the pilots — a kill never hides a round or a SPAD.
rep("smokeColumns.forEach(drawSmokeColumn);drawAmbientClouds();",
    "smokeColumns.forEach(drawSmokeColumn);drawAmbientClouds();explosions.forEach(drawExplosion);",
    "draw explosions")

# 13. AceQA snapshot: report the live explosion count.
rep("bombBlasts:bombBlasts.length,",
    "bombBlasts:bombBlasts.length,explosions:explosions.length,", "snapshot")

# 14. runCampaignPlaytest: wait for the v37 frames, exercise them, gate on them.
rep("await waitForV36Images();",
    "await waitForV36Images();await waitForV37Images();", "wait v37")
rep("powerCycle:null,pass:false}",
    "powerCycle:null,explosions:null,pass:false}", "report init")
rep("report.ambient=AceQA.ambient();report.pass=",
    "report.ambient=AceQA.ambient();report.explosions=AceQA.explosions();report.pass=",
    "report explosions")
rep("&&report.ambient.pass}catch",
    "&&report.ambient.pass&&report.explosions.pass}catch", "pass gate")

# 15. sprite evidence: draw the v37 frames and gate the evidence pass on them.
rep("var v34=exerciseV34Sprites();var v36=exerciseV36Overlays();return{pass:missing.length===0&&v34.pass&&v36.pass,total:expected.length,seen:seen,missing:missing,groups:groups,draws:spriteEvidenceState.draws,v34:v34,v36:v36}}",
    "var v34=exerciseV34Sprites();var v36=exerciseV36Overlays();var v37=exerciseV37Explosions();return{pass:missing.length===0&&v34.pass&&v36.pass&&v37.pass,total:expected.length,seen:seen,missing:missing,groups:groups,draws:spriteEvidenceState.draws,v34:v34,v36:v36,v37:v37}}",
    "sprite evidence v37")

# 16. v37 evidence + image waiter, right after the v36 helpers.
rep("function exerciseV36Overlays(){var drawn=0,missing=[];Object.keys(v36Art).forEach(function(k){var im=v36Art[k];if(im&&im.complete&&im.naturalWidth>0){try{drawFx(im,10,10,40,0,1);drawn++}catch(e){missing.push('v36:'+k+':draw')}}else missing.push('v36:'+k+':not-loaded')});return{pass:missing.length===0,drawn:drawn,missing:missing}}",
    """function exerciseV36Overlays(){var drawn=0,missing=[];Object.keys(v36Art).forEach(function(k){var im=v36Art[k];if(im&&im.complete&&im.naturalWidth>0){try{drawFx(im,10,10,40,0,1);drawn++}catch(e){missing.push('v36:'+k+':draw')}}else missing.push('v36:'+k+':not-loaded')});return{pass:missing.length===0,drawn:drawn,missing:missing}}
function exerciseV37Explosions(){var drawn=0,missing=[];v37Art.explosion.forEach(function(im,i){if(im&&im.complete&&im.naturalWidth>0){try{drawFx(im,10,10,40,0,1);drawn++}catch(e){missing.push('v37:frame'+i+':draw')}}else missing.push('v37:frame'+i+':not-loaded')});return{pass:missing.length===0&&drawn===8,drawn:drawn,missing:missing}}
/* v37 QA: wait for the explosion frames to load. */
function waitForV37Images(){return new Promise(function(res){var tries=0;var iv=setInterval(function(){tries++;var all=v37Art.explosion.slice();var done=all.every(function(im){return im&&im.complete});if(done||tries>200){clearInterval(iv);res(done)}},10)})}""",
    "v37 evidence helpers")

# 17. AceQA explosions exercise, right after the ambient exercise.
rep("fires:ambientFires.length,clouds:ambientClouds.length,smokeColumns:smokeColumns.length}},",
    """fires:ambientFires.length,clouds:ambientClouds.length,smokeColumns:smokeColumns.length}},
explosions:function(){
  if(!playing)reset();player.inv=999;player.fuel=100;
  enemies=[];explosions=[];enemyBullets=[];bullets=[];
  var e=qaEnemy('small',W/2,H*.3,0);enemies=[e];e.hp=0;update(1/60);
  var spawned=explosions.length>0;
  var smallOk=explosions.some(function(x){return x.r===44&&x.dur===0.55});
  var frames=v37Art.explosion.length===8&&v37Art.explosion.every(function(im){return im.complete&&im.naturalWidth>0});
  for(var i=0;i<70;i++)update(1/60);
  var expired=explosions.length===0;
  explosions=[];for(var j=0;j<20;j++)spawnExplosion(W/2,H*.3,'small');
  var capped=explosions.length<=8;
  explosions=[];spawnExplosion(W/2,H*.3,'boss');spawnExplosion(W/2,H*.3,'ghost');
  var bossR=explosions.length===2&&explosions[0].r===120&&explosions[1].r===140;
  return {pass:spawned&&smallOk&&frames&&expired&&capped&&bossR,spawned:spawned,smallOk:smallOk,frames:frames,expired:expired,capped:capped,bossR:bossR};
},""",
    "AceQA explosions exercise")

# 18. structural QA: v37 checks.
rep("return{pass:checks.every(function(c){return c.pass}),total:checks.length,checks:checks}}",
    """ok('v37: 8 explosion frames loaded',typeof v37Art!=='undefined'&&v37Art.explosion&&v37Art.explosion.length===8);
ok('v37: explosion cap at 8',typeof EXPLOSION_MAX==='number'&&EXPLOSION_MAX<=8);
ok('v37: explosion sizes capped (ghost 140)',typeof EXPLOSION_SIZE==='object'&&EXPLOSION_SIZE.ghost&&EXPLOSION_SIZE.ghost.r<=150);
ok('v37: explosion spawner wired',typeof spawnExplosion==='function'&&typeof explosionSizeFor==='function'&&typeof updateExplosions==='function'&&typeof drawExplosion==='function');
return{pass:checks.every(function(c){return c.pass}),total:checks.length,checks:checks}}""",
    "structural v37")

# 19. version badge.
rep('<span class="ver-badge">v36</span>', '<span class="ver-badge">v37</span>', "badge")

open(P, 'w', encoding='utf-8').write(h)
print('all v37 edits applied')
