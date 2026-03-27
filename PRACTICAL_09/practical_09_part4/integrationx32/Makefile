EXECUTABLE=IntegratingCandASM

all:
	nasm -f elf subtract.asm -o subtract.o -l starter.lst
	gcc -m32 -c main2.c
	gcc -m32 main2.o subtract.o -o $(EXECUTABLE)
	./$(EXECUTABLE)

#Clean folder
clean:
	rm -rf *o *.lst $(EXECUTABLE)