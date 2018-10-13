import cv2
import numpy as np

def get_file_name(id):
  id_with_leading_zeroes = '0' * (4 - len(str(id))) + str(id)
  return 'comics/%s.png' % (id_with_leading_zeroes)


mouse_x = 0
mouse_y = 0
clicked = False
split_row = True

# Handles mouse events.
def click_to_split(event, x, y, flags, param):
  global mouse_x, mouse_y, clicked
  if event == cv2.EVENT_MOUSEMOVE:
    mouse_x, mouse_y = x, y
  elif event == cv2.EVENT_LBUTTONDOWN:
    clicked = True

# Displays a window to annotate the comic. Returns either:
# * False if comic should be annotated again (the user made a mistake)
# * 0 if the comic is atomic
# * a tuple of bool and number if the comic can be split
#   - the bool indicates whether the tiles are next to each other
#   - the number indicates the fraction of the split
def split_comic(id, original_img):
  global mouse_x, mouse_y, clicked, split_row

  window_name = 'Comic %d' % (id)

  cv2.namedWindow(window_name)
  cv2.setMouseCallback(window_name, click_to_split)

  while True:
    img = np.array(original_img)
    width, height = len(img[0]), len(img)

    # display image with a bar at the mouse position
    start = (mouse_x,0) if split_row else (0,mouse_y)
    end = (mouse_x,height) if split_row else (width,mouse_y)
    cv2.line(img, start, end, 0, 2)
    cv2.imshow(window_name, img)

    key = cv2.waitKey(20) & 0xFF
    if key == 27:
      cv2.destroyAllWindows()
      break
    elif key == ord('s'):
      split_row = not split_row
    elif key == ord(' '):
      cv2.destroyAllWindows()
      return 0
    elif key == ord('r'):
      cv2.destroyAllWindows()
      return False

    if clicked:
      clicked = False
      cv2.destroyAllWindows()
      fraction = mouse_x / width if split_row else mouse_y / height
      print('Fraction is %f' % (fraction))
      return (split_row, fraction)


# Recursively annotates comic.
def annotate_comic(id, img = False):
  print('Please annotate the comic.')
  print('* left mouse button for separation')
  print('* space if comic is atomic')
  print('* \'r\' to retry / undo')
  print('* ESC to exit')

  # If this is the root of the call stack, load the image.
  if img is False:
    img = cv2.imread(get_file_name(id), cv2.IMREAD_GRAYSCALE)
  width, height = len(img[0]), len(img)
  
  res = split_comic(id, img)

  if res is None:
    return
  elif res is False:
    print('Retry.')
  elif res is 0:
    print('The comic is atomic.')
  else:
    split_row, fraction = res
    print('The comic is split at %f. Are comics next to each other? %s' % (fraction, str(split_row)))

    boundary = int(width * fraction) if split_row else int(height * fraction)
    first_img = img[:,:boundary] if split_row else img[:boundary,:]
    second_img = img[:,boundary:] if split_row else img[boundary:,:]
    annotate_comic(id, first_img)
    annotate_comic(id, second_img)


annotate_comic(1)
print('Exiting.')
