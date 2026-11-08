#!/usr/bin/env python3
"""bin/apply-v57-code.py — apply the v57 game-file edits for 1918.

Edits (each asserted to match exactly once before it is applied, so a
concurrent v55/v56 change to the same region fails loudly instead of
being silently overwritten):
 1. drawBlenderSprite: add noShadow (7th arg) + squashY (8th arg, pitch
    foreshorten). Ground objects keep the contact shadow by default.
 2. enemyAlt01 helper + drawEnemyShadow: the photographic shadow now rides
    the flight path's altitude (pathZ -> alt01) and the altitude-adjusted
    drawn size, so the shadow offsets/scales with height (v45 model).
 3. drawEnemy: noShadow=true, altitude size (+/-6%), pitch squash, and a
    damaged-pose fallback (a damaged image that never loaded falls back to
    the level sprite instead of vanishing).
 4. drawBoss fighter branch: noShadow=true (fighter aces fly clean).
 5. drawStaakenBoss + drawZeppelinBoss: remove the glued canvas shadow
    (the v45 photographic shadow in drawBossShadow carries the altitude).
 6. drawFokkerTriplaneSprite: draw the square frame as a square (the new
    triplane level is a proper top-down planform, not a flat strip).
 7. exerciseV57Airborne + AceQA.airborne wiring + campaign-report entry.
Does NOT touch: day-one flag, AdMob gating, IAP removal, 1P/2P screen,
stage card, 2P camo, v53 continuous flow, v55 Zeppelin fleet, v56 boss
damage, one-hit death / wingman buffers, ENEMY_ARCHETYPES sizes/radii,
SPRITE_FILLW, or the SPAD reference.
Usage: python3 bin/apply-v57-code.py
"""
import sys

PATH = "1918-ace-of-aces.html"


def replace_once(html, old, new, label):
    n = html.count(old)
    if n != 1:
        print(f"FAIL {label}: anchor found {n} times (want exactly 1)")
        return html, False
    return html.replace(old, new, 1), True


def main():
    html = open(PATH).read()
    ok = True

    # --- 1. drawBlenderSprite: noShadow + squashY -------------------------
    old = ("function drawBlenderSprite(im,x,y,size,rotation,alpha){if(!im||!im.complete||!im.naturalWidth)return false;"
           "ctx.save();ctx.translate(x,y);ctx.rotate(rotation||0);ctx.globalAlpha=alpha===undefined?1:alpha;"
           "ctx.shadowColor='rgba(0,0,0,.64)';ctx.shadowBlur=9;ctx.shadowOffsetY=7;"
           "ctx.drawImage(im,-size/2,-size/2,size,size);ctx.restore();noteSpriteDraw(im);return true}")
    new = ("/* v57 — airborne aircraft no longer take the glued canvas contact "
           "shadow (it pins them to the terrain). Pass noShadow=true and the "
           "aircraft is drawn clean; its altitude is read from the "
           "photographic v45 shadow (drawEnemyShadow / drawBossShadow) "
           "instead. squashY (optional, default 1) foreshortens the sprite "
           "vertically — the pitch of a climb or dive — without touching "
           "the ground objects that still need the contact shadow. */"
           "function drawBlenderSprite(im,x,y,size,rotation,alpha,noShadow,squashY){if(!im||!im.complete||!im.naturalWidth)return false;"
           "var sq=(typeof squashY==='number'&&squashY>0)?squashY:1;ctx.save();ctx.translate(x,y);ctx.rotate(rotation||0);"
           "ctx.globalAlpha=alpha===undefined?1:alpha;"
           "if(!noShadow){ctx.shadowColor='rgba(0,0,0,.64)';ctx.shadowBlur=9;ctx.shadowOffsetY=7}"
           "ctx.drawImage(im,-size/2,-size/2*sq,size,size*sq);ctx.restore();noteSpriteDraw(im);return true}")
    html, good = replace_once(html, old, new, "drawBlenderSprite")
    ok = ok and good

    # --- 2. enemyAlt01 helper + drawEnemyShadow ---------------------------
    old = ("function drawEnemyShadow(e){if(!e||e.hp<=0||e.pathHidden)return;"
           "var st=ENEMY_ARCHETYPES[e.archetype]||ENEMY_ARCHETYPES.small,set=spriteArt.aircraft[st.sprite];if(!set)return;"
           "drawAircraftShadow(e.x,e.y,bankedSprite(set,0),st.size,0)}")
    new = ("/* v57 — enemy altitude: the flight path's height (e.pathZ, from "
           "advancePathEnemy) mapped to a 0..1 altitude. PATH_LIBRARY z runs "
           "-28 (loop entry) to 58 (swoop peak), so (z+28)/86 spans the whole "
           "envelope. The same altitude reads the same size for every "
           "aircraft, so the v54 true scale holds at equal altitude. */"
           "function enemyAlt01(e){var z=(e&&typeof e.pathZ==='number')?e.pathZ:0;return Math.max(0,Math.min(1,(z+28)/86))}"
           "function drawEnemyShadow(e){if(!e||e.hp<=0||e.pathHidden)return;"
           "var st=ENEMY_ARCHETYPES[e.archetype]||ENEMY_ARCHETYPES.small,set=spriteArt.aircraft[st.sprite];if(!set)return;"
           "var alt01=enemyAlt01(e),size=st.size*(0.94+0.12*alt01);"
           "drawAircraftShadow(e.x,e.y,bankedSprite(set,0),size,0,alt01)}")
    html, good = replace_once(html, old, new, "drawEnemyShadow+enemyAlt01")
    ok = ok and good

    # --- 3. drawEnemy ------------------------------------------------------
    old = ("function drawEnemy(e){if(e.pathHidden)return;"
           "var st=ENEMY_ARCHETYPES[e.archetype]||ENEMY_ARCHETYPES.small,set=spriteArt.aircraft[st.sprite],"
           "im=(e.hp/e.max<=.25&&set.damaged)?set.damaged:(set.level||bankedSprite(set,e.bank||0));"
           "var size=st.size,heading=e.pathHeading===undefined?Math.atan2(e.vy||1,e.vx||0):e.pathHeading,"
           "rot=heading+Math.PI/2+(e.bank||0)*.2443;drawBlenderSprite(im,e.x,e.y,size,rot,1);")
    new = ("/* v57 — airborne: no glued contact shadow (the v45 photographic "
           "shadow carries the altitude now); the drawn size rides the path "
           "altitude (+/-6% — the same altitude reads the same size for every "
           "aircraft, so the v54 true scale holds at equal altitude); the "
           "pitch of a climb or dive foreshortens the airframe vertically; a "
           "damaged pose that never loaded falls back to the level sprite "
           "instead of vanishing. */"
           "function drawEnemy(e){if(e.pathHidden)return;"
           "var st=ENEMY_ARCHETYPES[e.archetype]||ENEMY_ARCHETYPES.small,set=spriteArt.aircraft[st.sprite],"
           "im=(e.hp/e.max<=.25&&set.damaged&&set.damaged.complete&&set.damaged.naturalWidth)?set.damaged:(set.level||bankedSprite(set,e.bank||0));"
           "var alt01=enemyAlt01(e),size=st.size*(0.94+0.12*alt01),"
           "heading=e.pathHeading===undefined?Math.atan2(e.vy||1,e.vx||0):e.pathHeading,"
           "rot=heading+Math.PI/2+(e.bank||0)*.2443,pitchSq=1-Math.min(.16,Math.abs(e.pathPitch||0)*.3);"
           "drawBlenderSprite(im,e.x,e.y,size,rot,1,true,pitchSq);")
    html, good = replace_once(html, old, new, "drawEnemy")
    ok = ok and good

    # --- 4. drawBoss fighter branch: noShadow ------------------------------
    old = "drawBlenderSprite(im,b.x,b.y,size,rot+bossRoll,1)}"
    new = ("drawBlenderSprite(im,b.x,b.y,size,rot+bossRoll,1,true)}"
           "/* v57: fighter aces fly clean — no glued contact shadow, the v45 "
           "photographic shadow carries the altitude */")
    html, good = replace_once(html, old, new, "drawBoss fighter noShadow")
    ok = ok and good

    # --- 5a. drawStaakenBoss: drop the glued canvas shadow -----------------
    old = ("ctx.rotate(Math.PI+bossBankRoll(b));"
           "ctx.shadowColor='rgba(0,0,0,.7)';ctx.shadowBlur=20;ctx.shadowOffsetY=14;"
           "if(im.complete&&im.naturalWidth){ctx.drawImage(im,-dw/2,-dh/2,dw,dh);noteSpriteDraw(im)}")
    new = ("ctx.rotate(Math.PI+bossBankRoll(b));"
           "/* v57: no glued canvas shadow — drawBossShadow carries the altitude */"
           "if(im.complete&&im.naturalWidth){ctx.drawImage(im,-dw/2,-dh/2,dw,dh);noteSpriteDraw(im)}")
    html, good = replace_once(html, old, new, "drawStaakenBoss shadow")
    ok = ok and good

    # --- 5b. drawZeppelinBoss: drop the glued canvas shadow (setup+reset) --
    old = ("ctx.rotate(Math.max(-.04,Math.min(.04,b.vx/2200))+Math.PI/2);"
           "ctx.shadowColor='rgba(0,0,0,.7)';ctx.shadowBlur=20;ctx.shadowOffsetY=14;"
           "if(im.complete&&im.naturalWidth){ctx.drawImage(im,-dw/2,-dh/2,dw,dh);noteSpriteDraw(im);"
           "ctx.shadowColor='transparent';ctx.shadowBlur=0;ctx.shadowOffsetY=0;drawZeppelinComponents(b,dw,dh)}")
    new = ("ctx.rotate(Math.max(-.04,Math.min(.04,b.vx/2200))+Math.PI/2);"
           "/* v57: no glued canvas shadow — drawBossShadow carries the altitude */"
           "if(im.complete&&im.naturalWidth){ctx.drawImage(im,-dw/2,-dh/2,dw,dh);noteSpriteDraw(im);"
           "drawZeppelinComponents(b,dw,dh)}")
    html, good = replace_once(html, old, new, "drawZeppelinBoss shadow")
    ok = ok and good

    # --- 6. drawFokkerTriplaneSprite: square frame, square draw ------------
    old = ("function drawFokkerTriplaneSprite(dw){var im=bankedSprite(spriteArt.aircraft.triplane,0);"
           "if(!im||!im.complete||!im.naturalWidth)return;var dh=dw*.62;ctx.drawImage(im,-dw/2,-dh/2,dw,dh)}")
    new = ("function drawFokkerTriplaneSprite(dw){var im=bankedSprite(spriteArt.aircraft.triplane,0);"
           "if(!im||!im.complete||!im.naturalWidth)return;var dh=dw;/* v57: the triplane level is a proper top-down planform now, "
           "not a flat strip — the square frame draws as a square, or the planform squashes flat */"
           "ctx.drawImage(im,-dw/2,-dh/2,dw,dh)}")
    html, good = replace_once(html, old, new, "drawFokkerTriplaneSprite")
    ok = ok and good

    # --- 7. exerciseV57Airborne (inserted after exerciseV54Scale) ----------
    exercise = (
        "function exerciseV57Airborne(){var out={pass:false,altMap:false,shadowModel:false,"
        "sizeAlt:false,sizeRatio:false,noGlueEnemy:false,noGlueBoss:false,bankPoses:false,"
        "damagedFallback:false,scaleIntact:false,dayOneIntact:false,oneTwoIntact:false,"
        "stageCardIntact:false};"
        "try{"
        "out.altMap=enemyAlt01({pathZ:-28})===0&&enemyAlt01({pathZ:58})===1"
        "&&Math.abs(enemyAlt01({pathZ:15})-0.5)<0.001"
        "&&enemyAlt01({pathZ:-100})===0&&enemyAlt01({pathZ:200})===1"
        "&&enemyAlt01({})===Math.max(0,Math.min(1,28/86));"
        "var sHi=shadowAltParams(H/2,0,1),sLo=shadowAltParams(H/2,0,0);"
        "out.shadowModel=sHi.off>sLo.off&&sHi.sc<sLo.sc&&sHi.al<sLo.al;"
        "var small=ENEMY_ARCHETYPES.small,gotha=ENEMY_ARCHETYPES.gotha;"
        "var hiSmall=small.size*(0.94+0.12*1),loSmall=small.size*(0.94+0.12*0);"
        "var hiGotha=gotha.size*(0.94+0.12*1),loGotha=gotha.size*(0.94+0.12*0);"
        "out.sizeAlt=hiSmall>loSmall&&hiGotha>loGotha"
        "&&Math.abs(hiSmall/small.size-1.06)<0.001&&Math.abs(loSmall/small.size-0.94)<0.001;"
        "out.sizeRatio=Math.abs((hiSmall/hiGotha)-(small.size/gotha.size))<0.001"
        "&&Math.abs((loSmall/loGotha)-(small.size/gotha.size))<0.001;"
        "out.noGlueEnemy=/drawBlenderSprite\\(im,e\\.x,e\\.y,size,rot,1,true,pitchSq\\)/.test(drawEnemy.toString());"
        "out.noGlueBoss=/drawBlenderSprite\\(im,b\\.x,b\\.y,size,rot\\+bossRoll,1,true\\)/.test(drawBoss.toString());"
        "var bankBad=[];Object.keys(spriteArt.aircraft).forEach(function(k){var set=spriteArt.aircraft[k];"
        "var l=bankedSprite(set,-1),c=bankedSprite(set,0),r=bankedSprite(set,1);"
        "if(!l||!c||!r||l===c||c===r||l===r||!l.complete||!c.complete||!r.complete"
        "||!l.naturalWidth||!c.naturalWidth||!r.naturalWidth)bankBad.push(k)});"
        "out.bankPoses=bankBad.length===0;"
        "if(!playing)reset();"
        "var fbBad=[];"
        "['small','red','triplane','riser'].forEach(function(arch){"
        "var st=ENEMY_ARCHETYPES[arch],set=spriteArt.aircraft[st.sprite];"
        "var saved=set.damaged;var broken=new Image();set.damaged=broken;"
        "spriteEvidenceState={seen:{},draws:0};"
        "var e=qaEnemy(arch,W/2,H*.34,0);e.hp=1;e.max=10;enemies=[e];draw();"
        "var key=st.sprite+'-level.png';"
        "if(!spriteEvidenceState.seen[key])fbBad.push(arch+':no-level-draw');"
        "set.damaged=saved;});"
        "out.damagedFallback=fbBad.length===0;"
        "var bad=[];Object.keys(ENEMY_ARCHETYPES).forEach(function(k){var st=ENEMY_ARCHETYPES[k],"
        "span=AIRCRAFT_SPAN_M[k],fw=SPRITE_FILLW[st.sprite];"
        "var wingspan=st.size*(fw/256),expected=SPAD_DRAWN_PX*(span/SPAD_SPAN_M);"
        "if(Math.abs(wingspan-expected)>1.5)bad.push(k)});"
        "out.scaleIntact=bad.length===0;"
        "out.dayOneIntact=typeof DAY_ONE_KEY!=='undefined'&&DAY_ONE_KEY==='1918-day-one'"
        "&&typeof markDayOne==='function'&&typeof adsAllowed==='function';"
        "out.oneTwoIntact=!!(document.getElementById('chooseSolo')&&document.getElementById('chooseCoop'));"
        "out.stageCardIntact=!!document.getElementById('stageCard');"
        "}catch(e){out.error=String(e&&e.message||e)}"
        "out.pass=out.altMap&&out.shadowModel&&out.sizeAlt&&out.sizeRatio&&out.noGlueEnemy"
        "&&out.noGlueBoss&&out.bankPoses&&out.damagedFallback&&out.scaleIntact"
        "&&out.dayOneIntact&&out.oneTwoIntact&&out.stageCardIntact;return out}"
    )
    # (v55 added a comment block between exerciseV54Scale and
    # exerciseV55ZeppelinFleet, so the anchor is v54's return + that comment.)
    anchor = "return out}\n/* v55 fleet exercise."
    html, good = replace_once(
        html, anchor,
        ("return out}\n" + exercise + "\n/* v55 fleet exercise."),
        "exerciseV57Airborne insert")
    ok = ok and good

    # --- 8. AceQA.airborne wiring -------------------------------------------
    old = "zeppelinFleet:function(){return exerciseV55ZeppelinFleet()},\n"
    new = ("zeppelinFleet:function(){return exerciseV55ZeppelinFleet()},\n"
           "airborne:function(){return exerciseV57Airborne()},\n")
    html, good = replace_once(html, old, new, "AceQA.airborne wiring")
    ok = ok and good

    # --- 9. campaign report: init + assignment + pass -----------------------
    old = "continuousFlow:null,scale:null,bossDamage:null,pass:false}"
    new = "continuousFlow:null,scale:null,bossDamage:null,airborne:null,pass:false}"
    html, good = replace_once(html, old, new, "report init airborne")
    ok = ok and good
    old = "report.bossDamage=AceQA.bossDamage();"
    new = "report.bossDamage=AceQA.bossDamage();report.airborne=AceQA.airborne();"
    html, good = replace_once(html, old, new, "report assignment airborne")
    ok = ok and good
    old = "report.continuousFlow.pass&&report.scale.pass&&report.bossDamage.pass}"
    new = "report.continuousFlow.pass&&report.scale.pass&&report.bossDamage.pass&&report.airborne.pass}"
    html, good = replace_once(html, old, new, "report pass airborne")
    ok = ok and good

    if not ok:
        print("ABORTED — no changes written (one or more anchors failed).")
        return 1
    open(PATH, "w").write(html)
    print("All v57 code edits applied to " + PATH)
    return 0


if __name__ == "__main__":
    sys.exit(main())
