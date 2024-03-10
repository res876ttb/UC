# UC

A unified compression tools wrapper

## Usage

```
Usage: uc <mode> [<arguments for each mode>]
Description: Unified Cmopression Tool Wraper

Availaile mode: [c, d, help]
  c:    Compress mode.
        Usage: uc c [<args>] <files to compress> ... <compressed file name>
        For .gz/.bz2/.xz, please use additional options: -gz/-bz2/-xz
        Ex. uc c -gz test.txt test2.txt
  d:    Decompress mode.
        Usage: uc d [<args>] <files to decompressed> ...
  help: print this help message

Common arguments for [c/d] mode:
  -p    Preview the given compressed file if supported.
  -v    Show which file is been compressed/decompressed.
  -vvv  Show verbose log of uc.

Arguments for [d] mode:
  -d    Create directories for each individual file to decompressed, move
        them into the directory, then perform decompression
        Ex. uc d -d test.tar.gz will generate a directory called test, then
        put all the decompressed files into it.
```

## TODO

- [ ] Preview files in the compressed file
- [ ] Check dependencies before start to compress/decompress