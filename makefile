AS = as
LD = ld

all: part-one part-two
	./out/part-one ./text/test1.txt
	./out/part-one ./text/input.txt
	./out/part-two ./text/test2.txt
	./out/part-two ./text/input.txt

part-one: part-one.o
	$(LD) -s -o out/part-one out/part-one.o -O1 -znosectionheader
part-one.o: part-one.s
	$(AS) -g part-one.s -o out/part-one.o

part-two: part-two.o
	$(LD) -s -o out/part-two out/part-two.o -O1 -znosectionheader
part-two.o: part-two.s
	$(AS) -g part-two.s -o out/part-two.o

clean:
	rm -f out/*
