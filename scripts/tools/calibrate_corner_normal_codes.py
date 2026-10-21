"""Correct Blender's near-pole custom-normal encoding without changing vectors.

Blender stores split normals as INT16_2D. Its public encoder can round the
azimuth to zero on a few narrow triangles. Solve the stored codes against the
actual decoded vectors, then enforce the caller's original vector tolerance.
This does not change topology, source target normals or any acceptance limit.
"""
import numpy as np


def calibrate(mesh, desired, tolerance=.002):
    if len(desired) != len(mesh.loops) or mesh.attributes['custom_normal'].data_type != 'INT16_2D':
        raise RuntimeError('Unsupported loop normal storage; inspect this Blender version')
    if not np.isfinite(np.asarray(desired, dtype=np.float64)).all():
        raise RuntimeError('Non-finite source normal vectors')
    before = [(normal.vector-target).length for normal, target in zip(mesh.corner_normals, desired)]
    bad = [index for index, error in enumerate(before) if error > tolerance]
    if len(bad) > 16:
        raise RuntimeError('Too many mismatched normals; inspect topology instead of calibrating')
    rows = []

    def set_code(index, code):
        mesh.attributes['custom_normal'].data[index].value = [int(v) for v in np.clip(np.rint(code), -32767, 32767)]
        mesh.update()

    def normal(index):
        return np.asarray(mesh.corner_normals[index].vector, dtype=np.float64)

    for index in bad:
        target = np.asarray(desired[index], dtype=np.float64)
        initial = list(mesh.attributes['custom_normal'].data[index].value)
        code = np.asarray(initial, dtype=np.float64)
        best = (float(np.linalg.norm(normal(index)-target)), code.copy())
        for unused in range(8):
            set_code(index, code)
            actual = normal(index)
            error = float(np.linalg.norm(actual-target))
            if error < best[0]: best = (error, code.copy())
            if error < .0002: break
            jacobian = []
            for coordinate in [0, 1]:
                trial = code.copy()
                step = 128 if code[coordinate]+128 < 32767 else -128
                trial[coordinate] += step
                set_code(index, trial)
                jacobian.append((normal(index)-actual)/step)
            delta = np.linalg.lstsq(np.asarray(jacobian).T, target-actual, rcond=None)[0]
            code = np.clip(np.rint(code+delta), -32767, 32767)
        code = best[1]
        if best[0] > .0002:
            for a in range(-4, 5):
                for b in range(-128, 129, 4):
                    candidate = code+np.array([a, b])
                    set_code(index, candidate)
                    error = float(np.linalg.norm(normal(index)-target))
                    if error < best[0]: best = (error, candidate.copy())
        set_code(index, best[1])
        rows.append({'loop': index, 'before_code': initial, 'after_code': best[1].tolist(),
                     'before_error': before[index], 'after_error': best[0]})
    after = [(normal.vector-target).length for normal, target in zip(mesh.corner_normals, desired)]
    if max(after) > tolerance:
        raise RuntimeError(f'Normal preservation still fails: {max(after)} > {tolerance}')
    return {'storage': 'Blender custom_normal INT16_2D', 'target_vectors_changed': False,
            'tolerance': tolerance, 'before_maximum': max(before), 'after_maximum': max(after),
            'corrected_loops': rows}
