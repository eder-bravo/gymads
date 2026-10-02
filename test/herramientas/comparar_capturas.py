"""Compara dos carpetas de capturas PNG píxel por píxel.

Uso: python3 test/herramientas/comparar_capturas.py ANTES DESPUES [TOLERANCIA]

Dos ejecuciones idénticas de Flutter no siempre dan los mismos bytes (el
suavizado del texto varía un poco), así que se ignoran diferencias de color
menores a TOLERANCIA (por defecto 48 de 255) y se informa cuántos píxeles
cambiaron más que eso en cada imagen.
"""
import struct
import sys
import zlib
from pathlib import Path


def leer(ruta):
    datos = Path(ruta).read_bytes()
    i, idat = 8, b''
    while i < len(datos):
        n = struct.unpack('>I', datos[i:i + 4])[0]
        tipo, cuerpo = datos[i + 4:i + 8], datos[i + 8:i + 8 + n]
        if tipo == b'IHDR':
            ancho, alto = struct.unpack('>II', cuerpo[:8])
        if tipo == b'IDAT':
            idat += cuerpo
        i += 12 + n
    crudo = zlib.decompress(idat)
    paso = ancho * 4 + 1
    filas, previa = [], bytearray(ancho * 4)
    for y in range(alto):
        filtro = crudo[y * paso]
        linea = bytearray(crudo[y * paso + 1:(y + 1) * paso])
        for x in range(len(linea)):
            a = linea[x - 4] if x >= 4 else 0
            b = previa[x]
            c = previa[x - 4] if x >= 4 else 0
            if filtro == 1:
                linea[x] = (linea[x] + a) & 255
            elif filtro == 2:
                linea[x] = (linea[x] + b) & 255
            elif filtro == 3:
                linea[x] = (linea[x] + ((a + b) >> 1)) & 255
            elif filtro == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                linea[x] = (linea[x] + pr) & 255
        filas.append(bytes(linea))
        previa = linea
    return ancho, alto, filas


def main():
    antes, despues = Path(sys.argv[1]), Path(sys.argv[2])
    tolerancia = int(sys.argv[3]) if len(sys.argv) > 3 else 48
    distintas = 0
    for archivo in sorted(antes.glob('*.png')):
        otro = despues / archivo.name
        if not otro.exists():
            print(f'FALTA   {archivo.name}')
            distintas += 1
            continue
        a, b = leer(archivo), leer(otro)
        if a[:2] != b[:2]:
            print(f'TAMAÑO  {archivo.name} {a[:2]} -> {b[:2]}')
            distintas += 1
            continue
        cambiados = 0
        for fa, fb in zip(a[2], b[2]):
            if fa == fb:
                continue
            for x in range(0, len(fa), 4):
                if max(abs(fa[x + k] - fb[x + k]) for k in range(3)) > tolerancia:
                    cambiados += 1
        if cambiados:
            print(f'CAMBIA  {archivo.name}: {cambiados} píxeles')
            distintas += 1
    print(f'{distintas} de {len(list(antes.glob("*.png")))} capturas cambiaron')
    sys.exit(1 if distintas else 0)


if __name__ == '__main__':
    main()
