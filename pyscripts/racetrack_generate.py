"""
Generate a file representing a racetrack, and write into a format that's easy
to parse in julia. 

Currently I cannot use Images with julia, or any other external library as it
seems, so for now just write a custom file format that's easy to parse.
"""
import argparse

from skimage.io import imread, imsave
from skimage.transform import resize

import numpy as np


TARGET_RACETRACK_SIZE = (50, 50)

boundary = 0
beginning = 1
ending = 2
filling = 3

black = [0, 0, 0]
red = [255, 0, 0]
green = [0, 255, 0]
white = [255, 255, 255]



def discretize_image(img):
    """Take a numpy array representing an image
    and discretize it into a set size, additionally
    interpreting the color:
    """

    # this method is not ideal because the thresholds are 
    # arbitrary. Do not use!

    assert(img.shape == (600, 600, 3))  # expect this input size

    resized = resize(img, TARGET_RACETRACK_SIZE + (3,))

    resized = (resized / 0.1).astype(np.int32)  # discretize

    black_pixels = resized.sum(axis=-1) < 25

    assert(black_pixels.any())

    red_pixels = (resized == np.array([10, 0, 0])).all(axis=-1).astype(int)
    green_pixels = (resized == np.array([0, 10, 0])).all(axis=-1).astype(int)

    all_pixels = np.stack([green_pixels, red_pixels,
                           black_pixels, np.ones(TARGET_RACETRACK_SIZE,
                                                 dtype=np.int32)])

    discrete_img = np.argmax(all_pixels, axis=0)
    return discrete_img


def discretize_image_coarsely(img):
    """
    Discretize the image without using thresholds. Instead, simply
    check if there's a pixel of a certain color in the input grid,
    and if there is, then assign it that color with the following priorities:
        - black
        - green
        - red
        - white
    """
    assert(img.shape == (600, 600, 3))  # expect this input size

    def check_color(img_slice, colors):
        for i, color in enumerate(colors):
            if (img_slice == np.array(color)).all(axis=-1).any():
                return i
        return len(colors)

    resized = np.zeros((50, 50), dtype=np.uint8)
    for i in range(50):
        for j in range(50):
            ratio = 600 // 50
            img_sl = img[ratio*i:ratio*(i+1),ratio*j:ratio*(j+1)]
            resized[i,j] = check_color(img_sl, [black, green, red])

    return resized



def render_discrete_img(path, img):
    """
    Inefficient debug script
    """
    discretized_img = np.zeros(TARGET_RACETRACK_SIZE + (3,),
                               dtype=np.uint8)

    def get_color(v):
        assert(0 <= v <= 3)
        if v == 0:
            return black
        elif v == 1:
            return green
        elif v == 2:
            return red
        return white

    for (i, j), val in np.ndenumerate(img):
        discretized_img[i, j, :] = get_color(val)

    imsave(path, discretized_img)


def write_processed_values(path, discrete_img):
    b = discrete_img.reshape(-1).tobytes()
    with open(path, 'wb') as fh:
        fh.write(b)



def main():
    parser = argparse.ArgumentParser(description="Convert a racetrack image "
                                     "into something easy to parse in julia")
    parser.add_argument("--path", help="THe path to the image", 
                        default="./racetrack.png")
    parser.add_argument("--debug", help="Path to the debug file",
                        default="debug.png")
    parser.add_argument("--out", help="Path to the output file, "
                        "to be parsed in julia",
                        default="racetrack.values")

    args = parser.parse_args()

    img = imread(args.path)
    dimg = discretize_image_coarsely(img)
    if args.debug:
        render_discrete_img(args.debug, dimg)
    write_processed_values(args.out, dimg)


if __name__ == "__main__":
    main()

