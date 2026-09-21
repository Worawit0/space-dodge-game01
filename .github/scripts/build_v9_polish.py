from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import os, math, random

GAME=Path(os.environ.get("GAME_ROOT","/tmp/ForsakenV9"))
V8=GAME/"assets/v8"
OUT=GAME/"assets/v9"
UI=OUT/"ui"
UI.mkdir(parents=True,exist_ok=True)

def save_panel(path,size=(96,96),accent=(148,103,55,255),fill=(15,11,14,248),red=False):
    w,h=size
    im=Image.new("RGBA",size,(0,0,0,0))
    d=ImageDraw.Draw(im)
    # shadow + outer iron frame
    d.rectangle((2,2,w-3,h-3),fill=(5,4,6,245),outline=(2,2,3,255),width=2)
    d.rectangle((5,5,w-6,h-6),outline=(62,49,45,255),width=3)
    d.rectangle((9,9,w-10,h-10),fill=fill,outline=accent,width=2)
    d.rectangle((14,14,w-15,h-15),outline=(60,45,42,255),width=1)
    # rivets + gothic corners
    corner=accent if not red else (142,34,37,255)
    for cx,cy in [(10,10),(w-11,10),(10,h-11),(w-11,h-11)]:
        d.ellipse((cx-3,cy-3,cx+3,cy+3),fill=(28,22,23,255),outline=corner,width=1)
        d.line((cx-2,cy,cx+2,cy),fill=(196,164,105,190),width=1)
    # small inner corner spikes
    for (cx,cy,sx,sy) in [(17,17,1,1),(w-18,17,-1,1),(17,h-18,1,-1),(w-18,h-18,-1,-1)]:
        pts=[(cx,cy),(cx+sx*10,cy),(cx,cy+sy*10)]
        d.polygon(pts,fill=(47,34,34,200))
    im.save(path)

def save_button(path,size=(320,64),state="normal"):
    if state=="hover":
        accent=(206,151,72,255); fill=(32,18,20,250)
    elif state=="pressed":
        accent=(170,80,54,255); fill=(38,13,16,250)
    elif state=="disabled":
        accent=(69,61,59,255); fill=(18,17,19,235)
    else:
        accent=(135,101,67,255); fill=(19,14,17,248)
    save_panel(path,size,accent,fill,red=(state=="pressed"))

for state in ["normal","hover","pressed","disabled"]:
    save_button(UI/f"button_{state}.png",state=state)
save_panel(UI/"panel.png")
save_panel(UI/"panel_red.png",accent=(118,40,43,255),fill=(20,8,11,250),red=True)
save_panel(UI/"slot.png",(96,96),accent=(109,83,59,255),fill=(12,10,13,248))
save_panel(UI/"hud_panel.png",(128,128),accent=(130,96,62,255),fill=(11,9,12,245))

# divider / ornaments
div=Image.new("RGBA",(512,22),(0,0,0,0))
d=ImageDraw.Draw(div)
d.line((22,11,490,11),fill=(97,72,51,220),width=2)
d.line((56,8,456,8),fill=(38,29,30,210),width=1)
for cx in [16,256,496]:
    d.polygon([(cx,3),(cx+8,11),(cx,19),(cx-8,11)],fill=(154,111,60,255),outline=(52,36,31,255))
div.save(UI/"divider.png")

# Bar frame / fill masks
bar=Image.new("RGBA",(384,28),(0,0,0,0)); d=ImageDraw.Draw(bar)
d.rounded_rectangle((1,1,382,26),radius=6,fill=(8,7,9,245),outline=(99,73,52,255),width=2)
d.rounded_rectangle((6,6,377,21),radius=4,fill=(20,17,19,255),outline=(42,34,33,255),width=1)
bar.save(UI/"bar_bg.png")

# Main menu title background: reuse V8 bg + central demon door silhouette + vignette
base_path=V8/"ui/title_bg.png"
base=Image.open(base_path).convert("RGBA") if base_path.exists() else Image.new("RGBA",(1280,720),(18,10,13,255))
door_path=V8/"gates/heart_00.png"
if door_path.exists():
    door=Image.open(door_path).convert("RGBA")
    scale=2.25
    door=door.resize((int(door.width*scale),int(door.height*scale)),Image.Resampling.NEAREST)
    door.putalpha(door.getchannel("A").point(lambda a:int(a*0.52)))
    base.alpha_composite(door,((1280-door.width)//2,115))
overlay=Image.new("RGBA",base.size,(0,0,0,0)); od=ImageDraw.Draw(overlay)
od.rectangle((0,0,1280,720),fill=(12,2,7,80))
for i in range(44):
    a=int(3+i*2.1)
    od.rectangle((i*7,i*4,1279-i*7,719-i*4),outline=(0,0,0,a),width=7)
overlay=overlay.filter(ImageFilter.GaussianBlur(1.0))
base=Image.alpha_composite(base,overlay)
base.save(UI/"title_bg.png")

# Battle background: darker center spotlight, blood halo.
battle_path=V8/"ui/battle_bg.png"
battle=Image.open(battle_path).convert("RGBA") if battle_path.exists() else base.copy()
ov=Image.new("RGBA",battle.size,(0,0,0,0)); od=ImageDraw.Draw(ov)
od.ellipse((365,95,915,575),fill=(78,8,15,70),outline=(138,28,28,120),width=8)
od.ellipse((430,150,850,530),outline=(65,16,20,150),width=3)
od.rectangle((0,0,1280,720),fill=(0,0,0,45))
battle=Image.alpha_composite(battle,ov)
battle.save(UI/"battle_bg.png")

# Game over background.
go=base.copy()
red=Image.new("RGBA",go.size,(72,0,8,95))
go=Image.alpha_composite(go,red)
go=go.filter(ImageFilter.GaussianBlur(0.5))
go.save(UI/"game_over_bg.png")

# inventory background with subtle columns
inv=Image.new("RGBA",(1280,720),(8,7,10,255))
dd=ImageDraw.Draw(inv)
for x in range(0,1280,64):
    dd.line((x,0,x,720),fill=(22,18,22,110),width=1)
for y in range(0,720,48):
    dd.line((0,y,1280,y),fill=(20,17,20,90),width=1)
dd.rectangle((0,0,1280,720),fill=(30,8,12,28))
inv.save(UI/"inventory_bg.png")

print("V9_UI_POLISH_OK")
