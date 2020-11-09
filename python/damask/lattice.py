import numpy as _np

kinematics = {
    'cF': {
        'slip' : _np.array([
                [+0,+1,-1 , +1,+1,+1],
                [-1,+0,+1 , +1,+1,+1],
                [+1,-1,+0 , +1,+1,+1],
                [+0,-1,-1 , -1,-1,+1],
                [+1,+0,+1 , -1,-1,+1],
                [-1,+1,+0 , -1,-1,+1],
                [+0,-1,+1 , +1,-1,-1],
                [-1,+0,-1 , +1,-1,-1],
                [+1,+1,+0 , +1,-1,-1],
                [+0,+1,+1 , -1,+1,-1],
                [+1,+0,-1 , -1,+1,-1],
                [-1,-1,+0 , -1,+1,-1],
                [+1,+1,+0 , +1,-1,+0],
                [+1,-1,+0 , +1,+1,+0],
                [+1,+0,+1 , +1,+0,-1],
                [+1,+0,-1 , +1,+0,+1],
                [+0,+1,+1 , +0,+1,-1],
                [+0,+1,-1 , +0,+1,+1],
               ],'d'),
        'twin' : _np.array([
                [-2, 1, 1,   1, 1, 1],
                [ 1,-2, 1,   1, 1, 1],
                [ 1, 1,-2,   1, 1, 1],
                [ 2,-1, 1,  -1,-1, 1],
                [-1, 2, 1,  -1,-1, 1],
                [-1,-1,-2,  -1,-1, 1],
                [-2,-1,-1,   1,-1,-1],
                [ 1, 2,-1,   1,-1,-1],
                [ 1,-1, 2,   1,-1,-1],
                [ 2, 1,-1,  -1, 1,-1],
                [-1,-2,-1,  -1, 1,-1],
                [-1, 1, 2,  -1, 1,-1],
                ],dtype=float),
    },
    'cI': {
        'slip' : _np.array([
                [+1,-1,+1 , +0,+1,+1],
                [-1,-1,+1 , +0,+1,+1],
                [+1,+1,+1 , +0,-1,+1],
                [-1,+1,+1 , +0,-1,+1],
                [-1,+1,+1 , +1,+0,+1],
                [-1,-1,+1 , +1,+0,+1],
                [+1,+1,+1 , -1,+0,+1],
                [+1,-1,+1 , -1,+0,+1],
                [-1,+1,+1 , +1,+1,+0],
                [-1,+1,-1 , +1,+1,+0],
                [+1,+1,+1 , -1,+1,+0],
                [+1,+1,-1 , -1,+1,+0],
                [-1,+1,+1 , +2,+1,+1],
                [+1,+1,+1 , -2,+1,+1],
                [+1,+1,-1 , +2,-1,+1],
                [+1,-1,+1 , +2,+1,-1],
                [+1,-1,+1 , +1,+2,+1],
                [+1,+1,-1 , -1,+2,+1],
                [+1,+1,+1 , +1,-2,+1],
                [-1,+1,+1 , +1,+2,-1],
                [+1,+1,-1 , +1,+1,+2],
                [+1,-1,+1 , -1,+1,+2],
                [-1,+1,+1 , +1,-1,+2],
                [+1,+1,+1 , +1,+1,-2],
               ],'d'),
        'twin' : _np.array([
                [-1, 1, 1,   2, 1, 1],
                [ 1, 1, 1,  -2, 1, 1],
                [ 1, 1,-1,   2,-1, 1],
                [ 1,-1, 1,   2, 1,-1],
                [ 1,-1, 1,   1, 2, 1],
                [ 1, 1,-1,  -1, 2, 1],
                [ 1, 1, 1,   1,-2, 1],
                [-1, 1, 1,   1, 2,-1],
                [ 1, 1,-1,   1, 1, 2],
                [ 1,-1, 1,  -1, 1, 2],
                [-1, 1, 1,   1,-1, 2],
                [ 1, 1, 1,   1, 1,-2],
                ],dtype=float),
    },
    'hP': {
        'slip' : _np.array([
                [+2,-1,-1,+0 , +0,+0,+0,+1],
                [-1,+2,-1,+0 , +0,+0,+0,+1],
                [-1,-1,+2,+0 , +0,+0,+0,+1],
                [+2,-1,-1,+0 , +0,+1,-1,+0],
                [-1,+2,-1,+0 , -1,+0,+1,+0],
                [-1,-1,+2,+0 , +1,-1,+0,+0],
                [-1,+1,+0,+0 , +1,+1,-2,+0],
                [+0,-1,+1,+0 , -2,+1,+1,+0],
                [+1,+0,-1,+0 , +1,-2,+1,+0],
                [-1,+2,-1,+0 , +1,+0,-1,+1],
                [-2,+1,+1,+0 , +0,+1,-1,+1],
                [-1,-1,+2,+0 , -1,+1,+0,+1],
                [+1,-2,+1,+0 , -1,+0,+1,+1],
                [+2,-1,-1,+0 , +0,-1,+1,+1],
                [+1,+1,-2,+0 , +1,-1,+0,+1],
                [-2,+1,+1,+3 , +1,+0,-1,+1],
                [-1,-1,+2,+3 , +1,+0,-1,+1],
                [-1,-1,+2,+3 , +0,+1,-1,+1],
                [+1,-2,+1,+3 , +0,+1,-1,+1],
                [+1,-2,+1,+3 , -1,+1,+0,+1],
                [+2,-1,-1,+3 , -1,+1,+0,+1],
                [+2,-1,-1,+3 , -1,+0,+1,+1],
                [+1,+1,-2,+3 , -1,+0,+1,+1],
                [+1,+1,-2,+3 , +0,-1,+1,+1],
                [-1,+2,-1,+3 , +0,-1,+1,+1],
                [-1,+2,-1,+3 , +1,-1,+0,+1],
                [-2,+1,+1,+3 , +1,-1,+0,+1],
                [-1,-1,+2,+3 , +1,+1,-2,+2],
                [+1,-2,+1,+3 , -1,+2,-1,+2],
                [+2,-1,-1,+3 , -2,+1,+1,+2],
                [+1,+1,-2,+3 , -1,-1,+2,+2],
                [-1,+2,-1,+3 , +1,-2,+1,+2],
                [-2,+1,+1,+3 , +2,-1,-1,+2],
               ],'d'),
        'twin' : _np.array([
                [-1,  0,  1,  1,     1,  0, -1,  2],   # shear = (3-(c/a)^2)/(sqrt(3) c/a) <-10.1>{10.2}
                [ 0, -1,  1,  1,     0,  1, -1,  2],
                [ 1, -1,  0,  1,    -1,  1,  0,  2],
                [ 1,  0, -1,  1,    -1,  0,  1,  2],
                [ 0,  1, -1,  1,     0, -1,  1,  2],
                [-1,  1,  0,  1,     1, -1,  0,  2],
                [-1, -1,  2,  6,     1,  1, -2,  1],  # shear = 1/(c/a) <11.6>{-1-1.1}
                [ 1, -2,  1,  6,    -1,  2, -1,  1],
                [ 2, -1, -1,  6,    -2,  1,  1,  1],
                [ 1,  1, -2,  6,    -1, -1,  2,  1],
                [-1,  2, -1,  6,     1, -2,  1,  1],
                [-2,  1,  1,  6,     2, -1, -1,  1],
                [ 1,  0, -1, -2,     1,  0, -1,  1],    # shear = (4(c/a)^2-9)/(4 sqrt(3) c/a)  <10.-2>{10.1}
                [ 0,  1, -1, -2,     0,  1, -1,  1],
                [-1,  1,  0, -2,    -1,  1,  0,  1],
                [-1,  0,  1, -2,    -1,  0,  1,  1],
                [ 0, -1,  1, -2,     0, -1,  1,  1],
                [ 1, -1,  0, -2,     1, -1,  0,  1],
                [ 1,  1, -2, -3,     1,  1, -2,  2],   # shear = 2((c/a)^2-2)/(3 c/a)  <11.-3>{11.2}
                [-1,  2, -1, -3,    -1,  2, -1,  2],
                [-2,  1,  1, -3,    -2,  1,  1,  2],
                [-1, -1,  2, -3,    -1, -1,  2,  2],
                [ 1, -2,  1, -3,     1, -2,  1,  2],
                [ 2, -1, -1, -3,     2, -1, -1,  2],
                ],dtype=float),
        },
}

# Kurdjomov--Sachs orientation relationship for fcc <-> bcc transformation
# from S. Morito et al., Journal of Alloys and Compounds 577:s587-s592, 2013
# also see K. Kitahara et al., Acta Materialia 54:1279-1288, 2006

relations = {
  'KS': {
    'cF' : _np.array([
        [[ -1,  0,  1],[  1,  1,  1]],
        [[ -1,  0,  1],[  1,  1,  1]],
        [[  0,  1, -1],[  1,  1,  1]],
        [[  0,  1, -1],[  1,  1,  1]],
        [[  1, -1,  0],[  1,  1,  1]],
        [[  1, -1,  0],[  1,  1,  1]],
        [[  1,  0, -1],[  1, -1,  1]],
        [[  1,  0, -1],[  1, -1,  1]],
        [[ -1, -1,  0],[  1, -1,  1]],
        [[ -1, -1,  0],[  1, -1,  1]],
        [[  0,  1,  1],[  1, -1,  1]],
        [[  0,  1,  1],[  1, -1,  1]],
        [[  0, -1,  1],[ -1,  1,  1]],
        [[  0, -1,  1],[ -1,  1,  1]],
        [[ -1,  0, -1],[ -1,  1,  1]],
        [[ -1,  0, -1],[ -1,  1,  1]],
        [[  1,  1,  0],[ -1,  1,  1]],
        [[  1,  1,  0],[ -1,  1,  1]],
        [[ -1,  1,  0],[  1,  1, -1]],
        [[ -1,  1,  0],[  1,  1, -1]],
        [[  0, -1, -1],[  1,  1, -1]],
        [[  0, -1, -1],[  1,  1, -1]],
        [[  1,  0,  1],[  1,  1, -1]],
        [[  1,  0,  1],[  1,  1, -1]],
        ],dtype=float),
    'cI' : _np.array([
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        [[ -1, -1,  1],[  0,  1,  1]],
        [[ -1,  1, -1],[  0,  1,  1]],
        ],dtype=float),
  },
  'GT': {
    'cF' : _np.array([
        [[ -5,-12, 17],[  1,  1,  1]],
        [[ 17, -5,-12],[  1,  1,  1]],
        [[-12, 17, -5],[  1,  1,  1]],
        [[  5, 12, 17],[ -1, -1,  1]],
        [[-17,  5,-12],[ -1, -1,  1]],
        [[ 12,-17, -5],[ -1, -1,  1]],
        [[ -5, 12,-17],[ -1,  1,  1]],
        [[ 17,  5, 12],[ -1,  1,  1]],
        [[-12,-17,  5],[ -1,  1,  1]],
        [[  5,-12,-17],[  1, -1,  1]],
        [[-17, -5, 12],[  1, -1,  1]],
        [[ 12, 17,  5],[  1, -1,  1]],
        [[ -5, 17,-12],[  1,  1,  1]],
        [[-12, -5, 17],[  1,  1,  1]],
        [[ 17,-12, -5],[  1,  1,  1]],
        [[  5,-17,-12],[ -1, -1,  1]],
        [[ 12,  5, 17],[ -1, -1,  1]],
        [[-17, 12, -5],[ -1, -1,  1]],
        [[ -5,-17, 12],[ -1,  1,  1]],
        [[-12,  5,-17],[ -1,  1,  1]],
        [[ 17, 12,  5],[ -1,  1,  1]],
        [[  5, 17, 12],[  1, -1,  1]],
        [[ 12, -5,-17],[  1, -1,  1]],
        [[-17,-12,  5],[  1, -1,  1]],
        ],dtype=float),
    'cI' : _np.array([
        [[-17, -7, 17],[  1,  0,  1]],
        [[ 17,-17, -7],[  1,  1,  0]],
        [[ -7, 17,-17],[  0,  1,  1]],
        [[ 17,  7, 17],[ -1,  0,  1]],
        [[-17, 17, -7],[ -1, -1,  0]],
        [[  7,-17,-17],[  0, -1,  1]],
        [[-17,  7,-17],[ -1,  0,  1]],
        [[ 17, 17,  7],[ -1,  1,  0]],
        [[ -7,-17, 17],[  0,  1,  1]],
        [[ 17, -7,-17],[  1,  0,  1]],
        [[-17,-17,  7],[  1, -1,  0]],
        [[  7, 17, 17],[  0, -1,  1]],
        [[-17, 17, -7],[  1,  1,  0]],
        [[ -7,-17, 17],[  0,  1,  1]],
        [[ 17, -7,-17],[  1,  0,  1]],
        [[ 17,-17, -7],[ -1, -1,  0]],
        [[  7, 17, 17],[  0, -1,  1]],
        [[-17,  7,-17],[ -1,  0,  1]],
        [[-17,-17,  7],[ -1,  1,  0]],
        [[ -7, 17,-17],[  0,  1,  1]],
        [[ 17,  7, 17],[ -1,  0,  1]],
        [[ 17, 17,  7],[  1, -1,  0]],
        [[  7,-17,-17],[  0, -1,  1]],
        [[-17, -7, 17],[  1,  0,  1]],
        ],dtype=float),
  },
  'GT_prime': {
    'cF' : _np.array([
        [[  0,  1, -1],[  7, 17, 17]],
        [[ -1,  0,  1],[ 17,  7, 17]],
        [[  1, -1,  0],[ 17, 17,  7]],
        [[  0, -1, -1],[ -7,-17, 17]],
        [[  1,  0,  1],[-17, -7, 17]],
        [[  1, -1,  0],[-17,-17,  7]],
        [[  0,  1, -1],[  7,-17,-17]],
        [[  1,  0,  1],[ 17, -7,-17]],
        [[ -1, -1,  0],[ 17,-17, -7]],
        [[  0, -1, -1],[ -7, 17,-17]],
        [[ -1,  0,  1],[-17,  7,-17]],
        [[ -1, -1,  0],[-17, 17, -7]],
        [[  0, -1,  1],[  7, 17, 17]],
        [[  1,  0, -1],[ 17,  7, 17]],
        [[ -1,  1,  0],[ 17, 17,  7]],
        [[  0,  1,  1],[ -7,-17, 17]],
        [[ -1,  0, -1],[-17, -7, 17]],
        [[ -1,  1,  0],[-17,-17,  7]],
        [[  0, -1,  1],[  7,-17,-17]],
        [[ -1,  0, -1],[ 17, -7,-17]],
        [[  1,  1,  0],[ 17,-17, -7]],
        [[  0,  1,  1],[ -7, 17,-17]],
        [[  1,  0, -1],[-17,  7,-17]],
        [[  1,  1,  0],[-17, 17, -7]],
        ],dtype=float),
    'cI' : _np.array([
        [[  1,  1, -1],[ 12,  5, 17]],
        [[ -1,  1,  1],[ 17, 12,  5]],
        [[  1, -1,  1],[  5, 17, 12]],
        [[ -1, -1, -1],[-12, -5, 17]],
        [[  1, -1,  1],[-17,-12,  5]],
        [[  1, -1, -1],[ -5,-17, 12]],
        [[ -1,  1, -1],[ 12, -5,-17]],
        [[  1,  1,  1],[ 17,-12, -5]],
        [[ -1, -1,  1],[  5,-17,-12]],
        [[  1, -1, -1],[-12,  5,-17]],
        [[ -1, -1,  1],[-17, 12, -5]],
        [[ -1, -1, -1],[ -5, 17,-12]],
        [[  1, -1,  1],[ 12, 17,  5]],
        [[  1,  1, -1],[  5, 12, 17]],
        [[ -1,  1,  1],[ 17,  5, 12]],
        [[ -1,  1,  1],[-12,-17,  5]],
        [[ -1, -1, -1],[ -5,-12, 17]],
        [[ -1,  1, -1],[-17, -5, 12]],
        [[ -1, -1,  1],[ 12,-17, -5]],
        [[ -1,  1, -1],[  5,-12,-17]],
        [[  1,  1,  1],[ 17, -5,-12]],
        [[  1,  1,  1],[-12, 17, -5]],
        [[  1, -1, -1],[ -5, 12,-17]],
        [[  1,  1, -1],[-17,  5,-12]],
        ],dtype=float),
  },
  'NW': {
    'cF' : _np.array([
        [[  2, -1, -1],[  1,  1,  1]],
        [[ -1,  2, -1],[  1,  1,  1]],
        [[ -1, -1,  2],[  1,  1,  1]],
        [[ -2, -1, -1],[ -1,  1,  1]],
        [[  1,  2, -1],[ -1,  1,  1]],
        [[  1, -1,  2],[ -1,  1,  1]],
        [[  2,  1, -1],[  1, -1,  1]],
        [[ -1, -2, -1],[  1, -1,  1]],
        [[ -1,  1,  2],[  1, -1,  1]],
        [[  2, -1,  1],[ -1, -1,  1]],
        [[ -1,  2,  1],[ -1, -1,  1]],
        [[ -1, -1, -2],[ -1, -1,  1]],
        ],dtype=float),
    'cI' : _np.array([
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        [[  0, -1,  1],[  0,  1,  1]],
        ],dtype=float),
  },
  'Pitsch': {
    'cF' : _np.array([
        [[  1,  0,  1],[  0,  1,  0]],
        [[  1,  1,  0],[  0,  0,  1]],
        [[  0,  1,  1],[  1,  0,  0]],
        [[  0,  1, -1],[  1,  0,  0]],
        [[ -1,  0,  1],[  0,  1,  0]],
        [[  1, -1,  0],[  0,  0,  1]],
        [[  1,  0, -1],[  0,  1,  0]],
        [[ -1,  1,  0],[  0,  0,  1]],
        [[  0, -1,  1],[  1,  0,  0]],
        [[  0,  1,  1],[  1,  0,  0]],
        [[  1,  0,  1],[  0,  1,  0]],
        [[  1,  1,  0],[  0,  0,  1]],
        ],dtype=float),
    'cI' : _np.array([
        [[  1, -1,  1],[ -1,  0,  1]],
        [[  1,  1, -1],[  1, -1,  0]],
        [[ -1,  1,  1],[  0,  1, -1]],
        [[ -1,  1, -1],[  0, -1, -1]],
        [[ -1, -1,  1],[ -1,  0, -1]],
        [[  1, -1, -1],[ -1, -1,  0]],
        [[  1, -1, -1],[ -1,  0, -1]],
        [[ -1,  1, -1],[ -1, -1,  0]],
        [[ -1, -1,  1],[  0, -1, -1]],
        [[ -1,  1,  1],[  0, -1,  1]],
        [[  1, -1,  1],[  1,  0, -1]],
        [[  1,  1, -1],[ -1,  1,  0]],
        ],dtype=float),
  },
  'Bain': {
    'cF' : _np.array([
        [[  0,  1,  0],[  1,  0,  0]],
        [[  0,  0,  1],[  0,  1,  0]],
        [[  1,  0,  0],[  0,  0,  1]],
        ],dtype=float),
    'cI' : _np.array([
        [[  0,  1,  1],[  1,  0,  0]],
        [[  1,  0,  1],[  0,  1,  0]],
        [[  1,  1,  0],[  0,  0,  1]],
        ],dtype=float),
  },
  'Burgers' : {
    'cI' : _np.array([
        [[ -1,  1,  1],[  1,  1,  0]],
        [[ -1,  1, -1],[  1,  1,  0]],
        [[  1,  1,  1],[  1, -1,  0]],
        [[  1,  1, -1],[  1, -1,  0]],

        [[  1,  1, -1],[  1,  0,  1]],
        [[ -1,  1,  1],[  1,  0,  1]],
        [[  1,  1,  1],[ -1,  0,  1]],
        [[  1, -1,  1],[ -1,  0,  1]],

        [[ -1,  1, -1],[  0,  1,  1]],
        [[  1,  1, -1],[  0,  1,  1]],
        [[ -1,  1,  1],[  0, -1,  1]],
        [[  1,  1,  1],[  0, -1,  1]],
      ],dtype=float),
    'hP' : _np.array([
        [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
        [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
        [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
        [[  -1, -1,   2, 0],[  0,  0,  0,  1]],

        [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
        [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
        [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
        [[  -1, -1,   2, 0],[  0,  0,  0,  1]],

        [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
        [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
        [[  -1,  2,  -1, 0],[  0,  0,  0,  1]],
        [[  -1, -1,   2, 0],[  0,  0,  0,  1]],
      ],dtype=float),
  },
}
