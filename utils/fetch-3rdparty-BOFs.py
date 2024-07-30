#!/bin/usr/python

import argparse
from pathlib import Path
import subprocess
import urllib.request
import yaml

SCRIPT_VERSION = "0.1"

def parse_args():
    parser = argparse.ArgumentParser(description="Usage: python fetch-3rdparty-BOFs.py <FILE> <BOFs src dir>\n")
    menu_group = parser.add_argument_group('Menu Options')

    # on/off flag argument type:
    menu_group.add_argument('-v', '--version', help="Show version of the script", action='store_true', required=False, default=None)

    menu_group.add_argument("yamlPath")

    menu_group.add_argument("bofsSrcDir")

    args = parser.parse_args()

    return args

if __name__ == "__main__":

    args = parse_args()
    yamlFile = Path(args.yamlPath)
    bofsSrcDir = Path(args.bofsSrcDir)
    
    if args.version:
        print("Version: " + SCRIPT_VERSION)

    with open(yamlFile) as f:
        for bofMetadata in yaml.safe_load_all(f):

            # get BOF details:
            name = bofMetadata['name']
            author = bofMetadata['author']
            os = bofMetadata['OS']
            formats = ".coff"
            arch = "x64, x86"
            if(os == "linux"):
                formats = ".elf"
                arch = ".x64, .x86, .aarch64, .arm"
            if(os == "cross"):
                formats = ".coff, .elf"
                arch = ".x64, .x86, .aarch64, .arm"

            # craft entry for BOFs table in build.zig
            print(".{ .name = \"" + name + "\", .dir = \"" + author + "/\", .formats = &.{ " + formats + " }, .archs = &.{ " + arch + " } },")

            # create directory (based on the BOF's author) where source files will reside
            destDir = bofsSrcDir / Path(bofMetadata['author'])
            if not destDir.is_dir():
                destDir.mkdir()

            # get BOF sources as defined in metadata:
            for src in bofMetadata['sources']:
                with urllib.request.urlopen(src) as f:
                    with open(destDir / Path(src).name, 'wb') as output:
                        output.write(f.read())

