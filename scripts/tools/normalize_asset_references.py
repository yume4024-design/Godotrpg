"""Mechanical reference packaging: crop/pad/scale RGBA copies, no repaint or mirror.

User source files remain intact. Background removal is a separate recorded Comfy job.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage

VIEWS = ['front','left','back','right']


def split_sheet(path):
    image = Image.open(path).convert('RGBA')
    pixels = np.array(image)
    labels, _ = ndimage.label(pixels[:,:,3] > 24)
    sizes = np.bincount(labels.ravel())
    if len(sizes) < 5:
        raise ValueError('Expected four separate full-body components')
    ids = sorted(np.argsort(sizes[1:])[-4:] + 1,
                 key=lambda i: ndimage.center_of_mass(labels == i)[1])
    if any(sizes[i] < 5000 for i in ids):
        raise ValueError('Incomplete or ambiguous sheet; inspect manually')
    result = {}
    for view, component in zip(VIEWS, ids):
        keep = ndimage.binary_dilation(labels == component, iterations=2)
        selected = pixels.copy()
        selected[:,:,3][~keep] = 0
        picture = Image.fromarray(selected)
        bbox = picture.getchannel('A').getbbox()
        result[view] = (picture.crop(bbox), {'sheet_box':bbox})
    return result


def normalize(sources, output, sheet=False):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    pictures = split_sheet(sources) if sheet else {}
    if not sheet:
        for view in VIEWS:
            im = Image.open(sources[view])
            if im.mode != 'RGBA' or im.getchannel('A').getextrema()[0] != 0:
                raise ValueError('Supply a real RGBA source; preprocess background separately')
            mask = im.getchannel('A').point(lambda a: 255 if a>16 else 0)
            bbox = mask.getbbox()
            if not bbox:
                raise ValueError('Empty foreground')
            pictures[view] = (im.crop(bbox), {'source_box':bbox})
    max_ratio = max(im.width/im.height for im,_ in pictures.values())
    target_height = int(896/max(1,max_ratio))
    records = []
    for view,(image,detail) in pictures.items():
        size = (round(image.width*target_height/image.height),target_height)
        image = image.resize(size,Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA',(1024,1024))
        canvas.alpha_composite(image,((1024-image.width)//2,960-image.height))
        path = output/(view+'.png')
        canvas.save(path)
        source = Path(sources if sheet else sources[view])
        records.append({'view':view,'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                        'output':str(path),'output_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                        'resized_size':size,'baseline_y':960,'canvas':[1024,1024],**detail})
    (output/'normalization.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf8')
    return records


def contact(folders, output):
    font = ImageFont.truetype('C:/Windows/Fonts/msjh.ttc',17)
    canvas = Image.new('RGB',(1200,len(folders)*320),'#46535d')
    draw = ImageDraw.Draw(canvas)
    for row,(name,folder) in enumerate(folders.items()):
        for column,view in enumerate(VIEWS):
            image = Image.open(Path(folder)/(view+'.png')).convert('RGBA')
            image.thumbnail((290,290))
            canvas.paste(image,(column*300,row*320+25),image)
            draw.text((column*300+4,row*320+3),name+' '+view,font=font,fill='white')
    canvas.save(output)


if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--sheet',type=Path)
    parser.add_argument('--manifest',type=Path)
    parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args()
    if bool(args.sheet)==bool(args.manifest):
        parser.error('Choose one --sheet or --manifest (view -> path)')
    normalize(args.sheet or json.loads(args.manifest.read_text(encoding='utf8')),args.output,bool(args.sheet))
