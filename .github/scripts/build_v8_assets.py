from pathlib import Path
from PIL import Image, ImageDraw, ImageStat
import os, shutil, re, random, math, wave, struct

GAME=Path(os.environ.get("GAME_ROOT","/tmp/ForsakenV8"))
ROOT=Path("/tmp/ext")
OUT=GAME/"assets/v8"
for d in [
    "player","npc","enemies/demon_a","enemies/blood_monster","enemies/flying_demon",
    "enemies/demon_slime","dungeon","gates","ui","props","items","fx","audio"
]:
    (OUT/d).mkdir(parents=True,exist_ok=True)

def one(pack,name,contains=None):
    hits=[p for p in (ROOT/pack).rglob(name) if p.is_file()]
    if contains:
        norm=contains.replace("\\","/")
        hits=[p for p in hits if norm in str(p).replace("\\","/")]
    if not hits:
        raise SystemExit(f"Missing {pack}: {name} contains={contains}")
    return hits[0]

def split_strip(src,outdir,prefix,frame_w=None,frame_h=None):
    im=Image.open(src).convert("RGBA")
    fh=frame_h or im.height
    fw=frame_w or fh
    count=max(1,im.width//fw)
    for i in range(count):
        crop=im.crop((i*fw,0,min((i+1)*fw,im.width),min(fh,im.height)))
        crop.save(outdir/f"{prefix}_{i:02d}.png")
    print("split",src.name,prefix,count)
    return count

# PLAYER: Foozle Lucifer Warrior, four directional idle/walk strips.
player_dir=OUT/"player"
for d in ["Down","Up","Left","Right"]:
    lo=d.lower()
    split_strip(one("warrior",f"Warrior{d}Idle.png"),player_dir,f"idle_{lo}")
    split_strip(one("warrior",f"Warrior{d}Walk.png"),player_dir,f"walk_{lo}")

# NPCs: Maren uses a tinted copy of the warrior idle-down frames; Sever uses Lucifer cultist.
def tint_copy(src,dst,tint):
    im=Image.open(src).convert("RGBA")
    px=im.load()
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,a=px[x,y]
            if a:
                px[x,y]=(min(255,int(r*tint[0])),min(255,int(g*tint[1])),min(255,int(b*tint[2])),a)
    im.save(dst)

maren_frames=sorted(player_dir.glob("idle_down_*.png"))
for i,p in enumerate(maren_frames):
    tint_copy(p,OUT/"npc"/f"maren_{i:02d}.png",(0.72,0.92,1.15))

sever_src=one("cultist","CultistDownIdle.png")
sever_tmp=OUT/"npc"/"_sever"
sever_tmp.mkdir(exist_ok=True)
count=split_strip(sever_src,sever_tmp,"idle")
for i,p in enumerate(sorted(sever_tmp.glob("idle_*.png"))):
    shutil.copy2(p,OUT/"npc"/f"sever_{i:02d}.png")
shutil.rmtree(sever_tmp)

# ENEMIES: Tiny RPG Demon A and Blood Monster A (100x100 cells).
def split_tiny(char,outname):
    out=OUT/"enemies"/outname
    fragment=f"/{char}/{char}/"
    for state,prefix in [("Idle","idle"),("Walk","walk"),("Attack01","attack"),("Hurt","hurt"),("Death","death")]:
        src=one("demons",f"{char}_{state}.png",fragment)
        im=Image.open(src).convert("RGBA")
        count=im.width//100
        for i in range(count):
            im.crop((i*100,0,(i+1)*100,100)).save(out/f"{prefix}_{i:02d}.png")
        print(char,state,count)
split_tiny("Demon_A","demon_a")
split_tiny("Blood Monster_A","blood_monster")

# Flying demon sheets.
fd=OUT/"enemies/flying_demon"
for srcname,count,prefix in [
    ("IDLE.png",4,"idle"),("FLYING.png",4,"walk"),("ATTACK.png",8,"attack"),
    ("HURT.png",4,"hurt"),("DEATH.png",7,"death")
]:
    src=one("flying",srcname)
    im=Image.open(src).convert("RGBA")
    fw=im.width//count
    for i in range(count):
        im.crop((i*fw,0,(i+1)*fw,im.height)).save(fd/f"{prefix}_{i:02d}.png")

# Demon Slime boss individual frames.
def numkey(p):
    m=re.search(r"(\d+)(?=\.png$)",p.name)
    return int(m.group(1)) if m else 0

def copy_seq(folder_fragment,prefix,outprefix):
    paths=[p for p in (ROOT/"boss").rglob("*.png") if folder_fragment in str(p).replace("\\","/") and p.name.startswith(prefix)]
    paths=sorted(paths,key=numkey)
    if not paths:
        raise SystemExit(f"No boss frames {folder_fragment} {prefix}")
    out=OUT/"enemies/demon_slime"
    for i,p in enumerate(paths):
        shutil.copy2(p,out/f"{outprefix}_{i:02d}.png")
    print("boss",outprefix,len(paths))
copy_seq("01_demon_idle","demon_idle_","idle")
copy_seq("02_demon_walk","demon_walk_","walk")
copy_seq("03_demon_cleave","demon_cleave_","attack")
copy_seq("04_demon_take_hit","demon_take_hit_","hurt")
copy_seq("05_demon_death","demon_death_","death")

# DUNGEON: choose opaque source tiles from Pixel_Poem free tileset.
tiles=Image.open(one("dungeon","Dungeon_Tileset.png")).convert("RGBA")
tiles.save(OUT/"dungeon/source_tileset.png")
tw=16
candidates=[]
for ty in range(max(1,tiles.height//tw)):
    for tx in range(max(1,tiles.width//tw)):
        crop=tiles.crop((tx*tw,ty*tw,(tx+1)*tw,(ty+1)*tw))
        if ImageStat.Stat(crop.getchannel("A")).mean[0] < 230:
            continue
        st=ImageStat.Stat(crop.convert("RGB"))
        bright=sum(st.mean)/3
        detail=sum(st.stddev)
        if 18<bright<215:
            candidates.append((detail,bright,tx,ty,crop))
if len(candidates)<4:
    raise SystemExit("Dungeon tileset did not yield enough usable tiles")
usable=[x for x in candidates if x[0]>7] or candidates
floor=min(usable,key=lambda x:abs(x[1]-65)+x[0]*0.2)
wall=max(usable,key=lambda x:x[0]+abs(x[1]-82)*0.03)
rest=[x for x in usable if (x[2],x[3]) not in [(floor[2],floor[3]),(wall[2],wall[3])]]
top=max(rest,key=lambda x:x[0]) if rest else wall
detail=sorted(rest,key=lambda x:abs(x[1]-floor[1]))[0] if rest else floor

def save_tile(info,name,scale=2):
    info[4].resize((tw*scale,tw*scale),Image.Resampling.NEAREST).save(OUT/"dungeon"/name)
save_tile(floor,"floor_tile.png")
save_tile(wall,"wall_tile.png")
save_tile(top,"wall_top.png")
save_tile(detail,"floor_detail.png")

# foreground rock cluster, coherent pixel palette.
rock=Image.new("RGBA",(192,96),(0,0,0,0))
rd=ImageDraw.Draw(rock)
random.seed(808)
for _ in range(22):
    x=random.randint(5,187); y=random.randint(32,90)
    rx=random.randint(8,26); ry=random.randint(5,13)
    c=random.choice([(38,31,31,255),(52,41,38,255),(64,49,43,255),(75,56,47,255)])
    rd.ellipse((x-rx,y-ry,x+rx,y+ry),fill=c,outline=(21,17,18,255),width=2)
rock.save(OUT/"dungeon/foreground_rock.png")

# DARK AGES UI: use source palette to build scalable 9-slice skins.
ui_src=Image.open(one("darkui","32x32-Tilesheet.png")).convert("RGBA")
ui_src.save(OUT/"ui/dark_ages_source.png")
colors=[px for px in ui_src.getdata() if px[3]>180]
freq={}
for c in colors: freq[c]=freq.get(c,0)+1
common=sorted(freq.items(),key=lambda kv:kv[1],reverse=True)[:60]
palette=[c for c,n in common if 12<sum(c[:3])/3<235]
dark=min(palette,key=lambda c:sum(c[:3])) if palette else (26,20,23,255)
light=max(palette,key=lambda c:sum(c[:3])) if palette else (188,151,96,255)
mid=palette[len(palette)//2] if palette else (88,65,52,255)
gold=(max(130,light[0]),max(95,int(light[1]*.92)),max(60,int(light[2]*.70)),255)

def panel_texture(path,size=(64,64),state="normal"):
    w,h=size
    im=Image.new("RGBA",size,(11,8,11,248))
    d=ImageDraw.Draw(im)
    border=mid
    if state=="hover": border=gold
    if state=="pressed": border=(max(35,gold[0]-35),max(28,gold[1]-35),max(20,gold[2]-35),255)
    if state=="disabled": border=(58,50,49,255)
    d.rectangle((1,1,w-2,h-2),outline=(4,3,5,255),width=2)
    d.rectangle((4,4,w-5,h-5),outline=border,width=3)
    d.rectangle((8,8,w-9,h-9),fill=(15,11,14,246),outline=(58,45,42,255),width=1)
    for cx,cy in [(7,7),(w-8,7),(7,h-8),(w-8,h-8)]:
        d.polygon([(cx,cy-4),(cx+4,cy),(cx,cy+4),(cx-4,cy)],fill=border)
    im.save(path)

panel_texture(OUT/"ui/panel_frame.png",(64,64))
panel_texture(OUT/"ui/button_normal.png",(160,48),"normal")
panel_texture(OUT/"ui/button_hover.png",(160,48),"hover")
panel_texture(OUT/"ui/button_pressed.png",(160,48),"pressed")
panel_texture(OUT/"ui/button_disabled.png",(160,48),"disabled")

# DEMON DOORS: crop three large variants, then make actual lift-opening frame sequences.
door=Image.open(one("door","!Demon Door.png")).convert("RGBA")
spans=[(1483,1637),(1723,1877),(1963,2117)]
for name,(x0,x1) in zip(["prison","temple","heart"],spans):
    base=door.crop((x0,5,x1,199))
    bbox=base.getchannel("A").getbbox()
    if bbox: base=base.crop(bbox)
    # fit to consistent canvas while preserving pixels
    canvas_w=max(96,base.width)
    canvas_h=max(160,base.height)
    for i in range(10):
        t=i/9.0
        lift=int((canvas_h+16)*t)
        frame=Image.new("RGBA",(canvas_w,canvas_h),(0,0,0,0))
        px=(canvas_w-base.width)//2
        py=canvas_h-base.height-lift
        frame.paste(base,(px,py),base)
        frame.save(OUT/"gates"/f"{name}_{i:02d}.png")

# Props from Infernus.
prop_map={
    "cage.png":"Infernus_Cage_3.png","altar.png":"Infernus_Altar1_1.png",
    "gore.png":"Infernus_GorePile_5.png","lantern.png":"Infernus_WallLantern_3.png",
    "shelf.png":"Infernus_Shelf_4.png","pillar.png":"Infernus_Pillar_2.png",
    "skull.png":"Infernus_Skull1_1.png","book.png":"Infernus_Book1_1.png"
}
for dst,src in prop_map.items():
    shutil.copy2(one("infernus",src),OUT/"props"/dst)

# Ritual circle - original simple pixel art compatible with the pack.
rit=Image.new("RGBA",(128,128),(0,0,0,0))
d=ImageDraw.Draw(rit)
for r,c,w in [(50,(125,19,22,220),4),(37,(86,13,17,230),3),(22,(150,25,24,210),2)]:
    d.ellipse((64-r,64-r,64+r,64+r),outline=c,width=w)
for ang in range(0,360,60):
    a=math.radians(ang)
    x=64+int(math.cos(a)*48); y=64+int(math.sin(a)*48)
    d.line((64,64,x,y),fill=(120,16,19,200),width=2)
d.polygon([(64,24),(98,86),(30,86)],outline=(167,31,28,235),width=3)
rit.save(OUT/"props/ritual_circle.png")

# ITEM ICONS from Lucifer equipment + original survival/key pixel icons.
equip_map={
    "rusted_sword.png":"Common Arming Sword.png",
    "bearded_axe.png":"Common Bearded Axe.png",
    "greatsword.png":"Common Greatsword.png",
    "ragged_shirt.png":"Common Ragged shirt.png",
    "chainmail.png":"Common ChainMail Chestpiece.png",
    "plate_harness.png":"Rare Plate Chestpiece.png"
}
for dst,src in equip_map.items():
    shutil.copy2(one("equipment",src),OUT/"items"/dst)

def icon(name,draw_fn):
    im=Image.new("RGBA",(32,32),(0,0,0,0)); d=ImageDraw.Draw(im); draw_fn(d); im.save(OUT/"items"/name)
icon("rust_key.png",lambda d:(d.rectangle((14,5,18,24),fill=(186,142,64,255)),d.ellipse((10,3,22,13),outline=(220,174,86,255),width=3),d.rectangle((18,19,26,22),fill=(186,142,64,255))))
icon("bell_sigil.png",lambda d:(d.ellipse((7,5,25,24),outline=(183,115,58,255),width=3),d.rectangle((14,22,18,27),fill=(183,115,58,255)),d.ellipse((12,24,20,29),fill=(124,54,42,255))))
icon("ration.png",lambda d:(d.rectangle((6,9,26,24),fill=(114,77,45,255),outline=(206,157,83,255),width=2),d.line((8,12,24,21),fill=(65,42,31,255),width=2)))
icon("bandage.png",lambda d:(d.rectangle((5,12,27,20),fill=(218,205,183,255),outline=(139,122,110,255),width=2),d.rectangle((13,10,19,22),fill=(230,218,196,255))))
icon("blue_vial.png",lambda d:(d.rectangle((12,8,20,25),fill=(55,119,192,230),outline=(164,205,238,255),width=2),d.rectangle((13,5,19,9),fill=(156,144,123,255))))
icon("torch_oil.png",lambda d:(d.ellipse((8,10,24,27),fill=(131,81,29,255),outline=(220,159,62,255),width=2),d.rectangle((12,5,20,11),fill=(82,62,48,255))))

# FX radial light.
light=Image.new("RGBA",(128,128),(255,255,255,0))
lp=light.load()
for y in range(128):
    for x in range(128):
        dist=math.sqrt((x-63.5)**2+(y-63.5)**2)/64.0
        a=int(max(0,1-dist)**1.8*255)
        lp[x,y]=(255,255,255,a)
light.save(OUT/"fx/light.png")

# Title and battle backgrounds using the chosen dungeon tiles.
floor_img=Image.open(OUT/"dungeon/floor_tile.png").convert("RGBA")
wall_img=Image.open(OUT/"dungeon/wall_tile.png").convert("RGBA")
def tile_fill(base,tile,rect):
    x0,y0,x1,y1=rect
    for y in range(y0,y1,tile.height):
        for x in range(x0,x1,tile.width):
            base.alpha_composite(tile,(x,y))
def backdrop(name,battle=False):
    W,H=1280,720
    im=Image.new("RGBA",(W,H),(13,9,12,255))
    tile_fill(im,floor_img,(0,0,W,H))
    # walls and columns
    for rect in [(0,0,W,105),(0,H-95,W,H),(0,0,95,H),(W-95,0,W,H)]:
        x0,y0,x1,y1=rect
        tile_fill(im,wall_img,rect)
    d=ImageDraw.Draw(im,"RGBA")
    if battle:
        d.ellipse((465,155,815,505),outline=(110,18,22,150),width=7)
        d.ellipse((510,200,770,460),outline=(75,12,16,130),width=3)
        for x in [310,970]:
            d.rectangle((x,110,x+70,610),fill=(24,17,20,210),outline=(78,57,50,230),width=5)
    else:
        d.ellipse((525,250,755,480),outline=(100,14,19,110),width=5)
        d.polygon([(640,270),(735,445),(545,445)],outline=(125,20,23,130),width=4)
    # vignette
    for k in range(28):
        a=int(4+k*2.4)
        d.rectangle((k*7,k*5,W-k*7-1,H-k*5-1),outline=(0,0,0,a),width=7)
    im.save(OUT/"ui"/name)
backdrop("title_bg.png",False)
backdrop("battle_bg.png",True)

# AUDIO: real horror SFX from the uploaded-equivalent CC0 pack.
audio_map={
    "ambient.mp3":"Ambient Wind (1).mp3",
    "footstep.mp3":"Metal Footsteps (1).mp3",
    "door.mp3":"Creaking Door (3).mp3",
    "monster_growl.mp3":"Monster Growl (1).mp3"
}
for dst,src in audio_map.items():
    shutil.copy2(one("horrorsfx",src),OUT/"audio"/dst)

# Small stable original WAV effects for UI/combat/support.
sr=22050
def wav(name,duration,fn):
    n=int(sr*duration)
    with wave.open(str(GAME/"assets/audio"/name),"wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        buf=bytearray()
        for i in range(n):
            t=i/sr
            v=max(-1,min(1,fn(t,i)))
            buf += struct.pack("<h",int(v*32767))
        w.writeframes(buf)
random.seed(22)
(GAME/"assets/audio").mkdir(parents=True,exist_ok=True)
wav("locked.wav",0.18,lambda t,i:0.20*math.sin(2*math.pi*220*t)*(1-t/0.18))
wav("pickup.wav",0.22,lambda t,i:0.17*math.sin(2*math.pi*(390+260*t)*t)*(1-t/0.22))
wav("shrine.wav",1.1,lambda t,i:0.12*(math.sin(2*math.pi*261.6*t)+0.45*math.sin(2*math.pi*392*t))*(1-t/1.1))
wav("ritual.wav",1.4,lambda t,i:0.14*math.sin(2*math.pi*(58+8*math.sin(t*4))*t)*(1-t/1.4)+random.uniform(-0.018,0.018))
wav("hit.wav",0.14,lambda t,i:random.uniform(-0.30,0.30)*(1-t/0.14))
wav("hurt.wav",0.22,lambda t,i:0.14*math.sin(2*math.pi*95*t)+random.uniform(-0.07,0.07)*(1-t/0.22))
wav("ui_click.wav",0.06,lambda t,i:0.12*math.sin(2*math.pi*540*t)*(1-t/0.06))

# Hard validation before Godot import.
required=[
    OUT/"player/idle_down_00.png",OUT/"player/walk_right_00.png",
    OUT/"npc/maren_00.png",OUT/"npc/sever_00.png",
    OUT/"enemies/demon_a/idle_00.png",OUT/"enemies/blood_monster/walk_00.png",
    OUT/"enemies/flying_demon/attack_00.png",OUT/"enemies/demon_slime/death_00.png",
    OUT/"dungeon/floor_tile.png",OUT/"dungeon/wall_tile.png",OUT/"dungeon/wall_top.png",
    OUT/"gates/prison_00.png",OUT/"gates/prison_09.png",OUT/"gates/heart_09.png",
    OUT/"ui/panel_frame.png",OUT/"ui/title_bg.png",OUT/"ui/battle_bg.png",
    OUT/"items/bearded_axe.png",OUT/"items/rust_key.png",OUT/"props/ritual_circle.png",
    OUT/"fx/light.png",OUT/"audio/ambient.mp3",OUT/"audio/door.mp3"
]
for p in required:
    if not p.exists() or p.stat().st_size < 80:
        raise SystemExit(f"Bad/missing V8 asset: {p}")
    print("OK",p.relative_to(GAME),p.stat().st_size)

print("V8_ASSET_BUILD_OK")
