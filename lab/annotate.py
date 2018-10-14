# Script for annotating comics whose detection failed with drag'n'drop.

import cv2
import numpy as np
from utils import *

start = (0, 0)
end = (0, 0)
dragging = False
done = False

# Handles mouse events.
def drag_to_annotate_tile(event, x, y, flags, param):
  global start, end, dragging, done

  if event == cv2.EVENT_LBUTTONDOWN:
    start = (x, y)
    end = start
    dragging = True
  if event == cv2.EVENT_MOUSEMOVE:
    end = (x, y)
  elif event == cv2.EVENT_LBUTTONUP:
    end = (x, y)
    dragging = False
    done = True

# Displays a window to annotate the comic tiles. Returns a list of the tiles'
# rectangle positions.
def annotate_comic(id):
  global start, end, dragging, done

  snapshots = [ cv2.imread(path_of_comic(id)) ]
  tiles = []
  window_name = 'Comic %d' % (id)

  cv2.namedWindow(window_name)
  cv2.setMouseCallback(window_name, drag_to_annotate_tile)

  while True:
    img = np.array(snapshots[-1])

    # display rectangle
    if dragging:
      cv2.rectangle(img, start, end, (0, 0, 255), 2)
    cv2.imshow(window_name, img)

    key = cv2.waitKey(20) & 0xFF
    if key == 27: # ESC to exit
      cv2.destroyAllWindows()
      return False
    elif key == ord(' '):
      cv2.destroyAllWindows()
      break
    elif key == ord('z') and len(tiles) > 0:
      snapshots = snapshots[:-1]
      tiles = tiles[:-1]
      print('Comic %d: Last annotation removed' % (id))

    if done:
      done = False
      img = np.array(snapshots[-1])
      cv2.rectangle(img, start, end, (255, 0, 0), 2)
      snapshots.append(img)
      tiles.append((start, end))
      print('Comic %d: %d tiles annotated: %s' % (id, len(tiles), str(tiles)))

  # done annotating, saving the result
  f = open(path_of_annotated_tiles(id), 'wb')
  for tile in tiles:
    line = '%d %d %d %d\n' % (tile[0][0], tile[0][1], tile[1][0], tile[1][1])
    f.write(line.encode('utf-8'))
  f.close()
  return True


def is_detection_valid(id):
  if not file_exists(path_of_detected_tiles(id)):
    return False
  with open(path_of_detected_tiles(id)) as f:
    lines = f.read().split('\n')
    if len(lines) == 0:
      print('Comic %d\'s detection file is empty' % (id))
      return False
    if lines[0] == 'needs review':
      print('Comic %d needs a review' % (id))
      return False
  return True


def annotate_all_comics():
  for id in range(max_comics):
    if file_exists(path_of_comic(id)):
      if file_exists(path_of_annotated_tiles(id)):
        print('Comic %d has already been annotated' % (id))
      elif is_detection_valid(id):
        print('Comic %d\'s tiles were detected automatically' % (id))
      else:
        success = annotate_comic(id)
        if not success:
          return


print("Please annotate the comics by dragging an annotation around the tiles. When")
print("you're done, press space. You can also press 'z' to undo the last annotation.")
print("When annotating, please notice:")
print("* the rectangle should overlap with the border of the comic tile")
print("* on squiggly or non-rectangular focus areas, choose the smallest rect that")
print("  includes everything")
annotate_all_comics()
print('Done.')
