"""
Render an episode
"""
import argparse
import os

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

    out_img = resize(discretized_img, (600, 600, 3))

    imsave(path, out_img)


def load_track(path):
    with open(path, 'rb') as fh:
        b = fh.read()

    return np.frombuffer(b, np.uint8).reshape(TARGET_RACETRACK_SIZE).copy()


def load_episode(path):

    with open(path, 'rb') as fh:
        b = fh.read()

    return np.frombuffer(b, np.uint8).reshape((-1, 2)).copy()


def render_episode(path_track, path_episode, path_frame_dir):

    track = load_track(path_track)
    episode = load_episode(path_episode)

    for i, (x, y) in enumerate(episode):
        track[x-1, y-1] = 2
        path = os.path.join(path_frame_dir,
                            "frame{}.png".format(str(i).zfill(3)))
        render_discrete_img(path, track)


def main():
    parser = argparse.ArgumentParser(description="Convert a racetrack image "
                                     "into something easy to parse in julia")
    parser.add_argument("--track", help="Path to the episode file",
                        default="racetrack.values")
    parser.add_argument("--episode", help="Path to the input episode", 
                        default="episode.values")
    parser.add_argument("--output_dir", help="Path to the output images",
                        default="racetrack-frames")

    args = parser.parse_args()
    render_episode(args.track, args.episode, args.output_dir)


if __name__ == "__main__":
    main()

