delete $Box*

fn brushPaint r d =
(
	if((r / d) <= 1.0) do return #([0, 0, 0])
	
	c = ((r / d) ^ 2) 
	print "---" 
	print c
	m = #()

	for i in 1 to c  collect 
	(	
		for k in 1 to 10 do
		(
			x = random -r r
			y = random -r r
			z = 0
					
			p = [x, y, z] 
			u = for ii in m where distance ii p < d collect ii
			if(u.count == 0 and distance [0, 0, 0] p < r) do 
			(
				append m p	
				exit
			)
		)
	)
	
	return m
)

r = 800
d = 30

lol = brushPaint r d 

for i in lol do box pos: i
	