DOT=dot

default: cleanup-states.ps

%.ps: %.dot
	$(DOT) -Tps $< -o $@

clean:
	rm -f *.ps
