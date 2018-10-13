import cv2
import numpy as np
import os.path
import math

WHITE = 255
BLACK = 0
FLOODED = 100

def get_file_name(id):
  id_with_leading_zeroes = '0' * (4 - len(str(id))) + str(id)
  return 'comics/%s.png' % (id_with_leading_zeroes)

def get_file_name_tiles(id):
  id_with_leading_zeroes = '0' * (4 - len(str(id))) + str(id)
  return 'tiles_generated/%s.txt' % (id_with_leading_zeroes)

# Yields all pixels in the given area.
def pixels(img, only_border = False, left=0, top=0, right=math.inf, bottom=math.inf):
  height, width = img.shape
  for y in range(max(0, top), min(height, bottom+1)):
    for x in range(max(0, left), min(width, right+1)):
      if not only_border or x == 0 or x == width-1 or y == 0 or y == height-1:
        yield x, y

# Floods all pixels with the given color and turns them into another color.
# Also, yields every colored pixel.
def flood(img, x, y, from_color=WHITE, to_color=FLOODED):
  height, width = img.shape
  count, wavefront = 0, [ (x,y) ]
  while len(wavefront) > 0:
    x,y = wavefront[0]
    wavefront = wavefront[1:]
    if 0 <= x < width and 0 <= y < height and img[y][x] == from_color:
      img[y][x] = to_color
      count += 1
      yield x,y
      if count % 5000 == 0:
        cv2.imshow('Comic', img)
        cv2.waitKey(1)
      for pos in [ (x-1,y), (x,y-1), (x+1,y), (x,y+1) ]:
        wavefront.append(pos)

# Loads an image and detects the tiles by doing this:
# * Converting image to black / white
# * Treating pixels adjacent to the white part of the border as the background,
#   the rest as the foreground.
# * Flooding parts of the foreground and frame them with rectangles.
#
# The function returns a list of tiles as well as the number of free content
# and the number of artifacts encountered. These metrics will allow for an
# informed decision about whether the process is applicable to the comic.
def detect_tiles(id):
  print('Reading comic #%d' % (id))
  img = cv2.imread(get_file_name(id), cv2.IMREAD_GRAYSCALE)
  cv2.imshow('Comic', img)
  cv2.waitKey(1)

  # Make the image just black and white
  print('Making image truly black and white')
  for x,y in pixels(img):
    img[y][x] = WHITE if img[y][x] > 220 else BLACK
  cv2.imshow('Comic', img)
  cv2.waitKey(20)

  # Flood the background, starting from the white border pixels
  print('Flooding background')
  for x,y in pixels(img, only_border = True):
    for xx,yy in flood(img, x, y):
      pass
  cv2.imshow('Comic', img)
  cv2.waitKey(1)

  # Delete actual content: Make background black, foreground white
  print('Abstracting comic tiles')
  for x,y in pixels(img):
    img[y][x] = BLACK if img[y][x] == FLOODED else WHITE
  cv2.imshow('Comic', img)
  cv2.waitKey(1)

  # Flood parts of the foreground
  print('Detecting comic tiles')
  tiles = []
  free_content, artifacts = 0, 0
  for x,y in pixels(img):
    if img[y][x] != WHITE:
      continue
      
    count, left, top, right, bottom = 0, x, y, x, y

    for xx,yy in flood(img, x, y, to_color = BLACK):
      count += 1
      left = min(left, xx)
      top = min(top, yy)
      right = max(right, xx)
      bottom = max(bottom, yy)
    cv2.imshow('Comic', img)
    cv2.waitKey(1)

    # The found foreground element is considered an artifact if it's small.
    # If it's bigger, it can either be free content or a tile.
    # If it's too small to be a tile or it's not rectangular, it's free content.
    area = (right - left + 1) * (bottom - top + 1)
    if area < 100:
      artifacts += 1
      continue
    if area < 10000:
      free_content += 1
      print('Content too small (area=%d), considered free' % (area))
      continue
    
    percentage_filled = count / area
    if percentage_filled < 0.9:
      free_content += 1
      print('Content is not rectangular (%f%% of rect is content), considered free' % (100 * percentage_filled))
      continue

    print('Tile found LTRB(%d,%d,%d,%d). %d pixels, %f%% filled' % (left, top, right, bottom, area, 100 * percentage_filled))
    tiles.append((left,top, right,bottom))

  for l,t,r,b in tiles:
    cv2.rectangle(img, (l,t), (r,b), WHITE, 2)
  cv2.imshow('Comic', img)
  cv2.waitKey(1)

  # Order the tiles and display their numbers.
  print('Ordering tiles')
  tiles.sort(key=lambda tile: tile[1] * 10 + tile[0])

  for i, tile in enumerate(tiles):
    text_size, _ = cv2.getTextSize(str(i), cv2.FONT_HERSHEY_PLAIN, 4, 4)
    center = ((tile[0] + tile[2]) // 2, (tile[1] + tile[3]) // 2)
    bottom_left = (center[0] - text_size[0] // 2, center[1] + text_size[1] // 2)
    cv2.putText(img, str(i), bottom_left, cv2.FONT_HERSHEY_PLAIN, 4, WHITE, 4)
    cv2.imshow('Comic', img)

  return tiles, free_content, artifacts, img.size


# Calls the detecter, then validates the result and saves it.
# Returns false if the comic was not analyzed.
# Otherwise, the validity and the comic image size is returned.
def detect_and_save_tiles_of_comic(id):
  if not os.path.isfile(get_file_name(id)):
    return False

  print('===')
  if os.path.isfile(get_file_name_tiles(id)) and False: # todo
    print('Tiles for comic %d already exists.' % (id))
    return False
  
  tiles, free_content, artifacts, img_size = detect_tiles(id)
  free_content_percentage = free_content / (free_content + len(tiles))
  first_tile_area_percentage = 0 if len(tiles) == 0 else ((tiles[0][2] - tiles[0][0]) * (tiles[0][3] - tiles[0][1]) / img_size)
  valid = len(tiles) > 0 and (free_content == 0 or first_tile_area_percentage > 0.8)

  print('Found %d tiles:' % (len(tiles)))
  for i, tile in enumerate(tiles):
    print('Tile #%d: LTRB%s' % (i, str(tile)))
  print('%d tiles, %d free content, %d artifacts' % (len(tiles), free_content, artifacts))
  print('%f%% of content is free' % (100 * free_content / (free_content + len(tiles))))
  print('This result is considered %svalid' % ('' if valid else 'not '))
  
  f = open(get_file_name_tiles(id), 'wb')
  if not valid:
    f.write('needs review\n'.encode('utf-8'))
  for tile in tiles:
    line = '%d %d %d %d\n' % (tile[0], tile[1], tile[2], tile[3])
    f.write(line.encode('utf-8'))
  f.close()

  cv2.waitKey(100) & 0xFF
  return valid, img_size


def detect_and_save_tiles_of_all_comics():
  num_valid, num_comics, num_pixels = 0, 0, 0

  # Interesting comics: 1, 7, 13, 15, 18, 20, 24, 34, 35, 39, 40, 41, 44, 46,
  # 50, 66, 80, 82, 92, 98, 99, 126, 133, 224, 304
  for id in range(0, 10000):
    res = detect_and_save_tiles_of_comic(id)

    if res == False:
      continue # comic was not analyzed

    valid, img_size = res
    num_valid += 1 if valid else 0
    num_comics += 1
    num_pixels += img_size

  print('===')
  print('%d pixels of %d comics analyzed.' % (num_pixels, num_comics))
  print('The analysis of %d comics (%d%%) resulted in valid tiles.' % (num_valid, 100 * num_valid / num_comics))


#detect_and_save_tiles_of_comic(1)
detect_and_save_tiles_of_all_comics()
