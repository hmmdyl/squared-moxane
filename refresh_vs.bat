RMDIR /S /Q .dub
RMDIR /S /Q .vs
dub build --arch=x86_64 --compiler=dmd --build=debug
dub generate visuald --arch=x86_64 --compiler=dmd --build=debug
cd unittest
RMDIR /S /Q .dub
RMDIR /S /Q .vs
dub build --arch=x86_64 --compiler=dmd --build=debug
dub generate visuald --arch=x86_64 --compiler=dmd --build=debug