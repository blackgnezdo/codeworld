{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE PackageImports    #-}
{-# LANGUAGE RebindableSyntax #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ParallelListComp #-}
{-# LANGUAGE RecordWildCards #-}

-- | Primitive Turtle commands for doing Turtle graphics. The commands
-- follow the original LOGO naming convention, but they integrate
-- seamlessly with the rest of CodeWorld.
module Extras.Turtle(
    -- $intro
    Turtle, TurtleCommand, TurtleProgram
    -- * Standard Turtle commands
    , fd, bk, rt, lt, seth, setxy, home, pu, pd
    -- * Specific Turtle commands (only in CodeWorld)
    , overxy, sethome, origin, turtle
    , randomized, repeatRandom
    -- * Program control (re-exported from "Extras.Util")
    , repeat, run, foreach, forloop
    -- * Tracks
    , Track, track, tracks, partialTracks, randomTracks
    , trackLength, alongTrack
    -- * Drawing extensions
    , polylines, thickPolylines, solidPolygons, dottylines, dottyline
    -- * Examples
    , turtleExamples
    -- * Custom Turtles
    , customTurtle, turtlePosition, turtleAngle,
    ) where

import Prelude
import Extras.Cw(slideshow,randomDrawingOf)
import Extras.Op
import Extras.Util

-------------------------------------------------------------------------------
-- $intro
-- = Turtle API
--
-- To use the extra features in this module, you must begin your code with this
-- line:
--
-- > import Extras.Turtle
--
-- This module allows you to use 'Turtle' programs to create
-- Turtle graphics.
-- For general information about Turtle graphics, you can consult
-- the Wikipedia page at <https://en.wikipedia.org/wiki/Turtle_graphics>
--
-- This module defines primitive Turtle commands to move and turn
-- a Turtle. Two functions, 'run' and 'repeat', can be used
-- to create new Turtle commands out of lists of commands.
-- The primitive Turtle commands in this module follow the command names,
-- syntax and semantics of the original LOGO commands as much as possible,
-- but this module is not a standalone LOGO interpreter.
-- Instead, Turtle programs in this module can be
-- used to create Tracks, which are lists of Points. You can then
-- feed those Tracks into regular CodeWorld graphical primitives,
-- such as 'polyline', 'curve' or 'polygon'. You can also use
-- the CodeWorld language to process the list of Points further
-- or to combine the shapes generated by a Turtle program with
-- shapes generated in other ways.
--
-- Example:
--
-- > program = drawingOf(polyline(track(turtleProgram)))
-- >
-- > turtleProgram = repeat(4, [fd(1), rt(90) ])
--
-- The example above will show a square of side length 1 with
-- its lower left corner at the origin.


-------------------------------------------------------------------------------
-- Turtle
-------------------------------------------------------------------------------

-- | A Turtle data structure contains information about the current state
-- of a Turtle, such as its current position, its current heading and
-- whether its pen is up or down. You cannot manipulate the inner
-- workings of this structure. Instead, you use Turtle programs to
-- change the internal state of a Turtle.
--
-- A Turtle is initially positioned at the origin, with the pen
-- down and pointing upwards. You can use the command 'sethome'
-- to reset the initial position to a different point.
data Turtle = Turtle
  { position :: Point
  , heading :: Point
  , trace :: [Point]
  , traces :: [[Point]]
  , pen :: Pen
  , rndNumbers :: [Number]
  }

data Pen = Pu | Pd

homePosition = (0,0)
homeHeading = (0,1)

initialTurtle :: Turtle
initialTurtle = Turtle
  { position = homePosition
  , heading = homeHeading
  , trace = [homePosition]
  , traces = []
  , pen = Pd
  , rndNumbers = []
  }

-- | A @customTurtle(x,y,angle)@ is a Turtle positioned at the point @(x,y)@,
-- which is pointing in the direction specified by the given @angle@,
-- where the angle is measured in
-- the normal CodeWorld way, i.e., 0 means pointing to the right,
-- and the angles increase counter-clockwise.
-- You can use this Turtle to have finer control over the Turtle.
--
-- Notes:
--
-- (1) Do not use the commands 'pu' and 'pd' on custom turtles, because
-- they do not have any visible effect. You must generate your own tracks
-- explicitly with the help of the 'turtlePosition' function.
-- (2) Do not use 'randomized' either,
-- because a custom turtle does not have access to random numbers.
-- (3) Probably, the only Turtle commands that are useful with custom
-- turtles are 'fd', 'bk', 'rt' and 'lt'. Any other handling of custom turtles
-- should be done with regular CodeWorld functions.
--
-- Example:
--
-- > program = randomDrawingOf(draw)
-- >   where
-- >   draw(random) = colored(thickPolyline(turtleTrack,0.2),red)
-- >     where
-- >     turtleTrack = forloop(input,cond,next,output)
-- >     input = (customTurtle(-10,-10,0), random)
-- >     cond(t,_) = x < 12 && y < 12 where (x,y) = turtlePosition(t)
-- >     next(t,r) = ( run([mayTurn(r#1), fd(2*r#2)])(t), rest(r,2) )
-- >     output(t,_) = turtlePosition(t)
-- >     mayTurn(r) = if r < 0.5 then turned else itself
-- >     turned(t) = if turtleAngle(t) < 45 then lt(90)(t) else rt(90)(t)
-- >
--
-- The example above randomly moves a custom turtle either up or to the right.
-- The turtle starts at the lower left corner of the output,
-- and it moves until it reaches either the top or the
-- right side of the output, whichever is reached first. This example
-- uses 'randomDrawingOf' from "Extras.Cw" and 'itself' from "Extras.Util".
customTurtle :: (Number,Number,Number) -> Turtle
customTurtle(x,y,angle) = initialTurtle
  { position = (x,y)
  , heading = rotatedPoint((1,0),angle)
  , trace = [(x,y)]
  , pen = Pu
  }

-- | The current position of the given Turtle.
turtlePosition :: Turtle -> Point
turtlePosition = position

-- | The orientation of the given Turtle measured in the normal way
-- that CodeWorld uses angles, so that 0 means pointing to
-- the right, and angles increase counter-clockwise.
turtleAngle :: Turtle -> Number
turtleAngle(turtle) = vectorDirection(turtle.#heading)

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------

-- | A Turtle command is a function that modifies the state of a Turtle.
type TurtleCommand = Turtle -> Turtle

-- | A Turtle program is a sequence of Turtle commands.
-- You can use the function
-- 'run' to convert a Turtle program into a single Turtle command that will
-- work the same way as the built-in Turtle commands. This type alias is not
-- used in this module, but you can use it in your code to specify the type of
-- a Turtle program. The examples in the documentation of 'sethome' and
-- 'overxy' show how you can use it.
type TurtleProgram = [TurtleCommand]

-- | A Track is a list of Points.
-- Tracks are generated by Turtle commands.
type Track = [Point]

-- | Convert a Turtle command into a Track. This is a simplified version
-- of 'tracks' that can be used when you know for sure that your Turtle
-- command will create only one Track. When that is not the case, the
-- different tracks will be joined together into a single Track, as
-- if the Turtle pen was always down.
track :: TurtleCommand -> Track
track(cmd) = cmd.#tracks.#concatenation

-- | Convert a Turtle command into a list of Tracks. A Track ends when
-- you use the 'pu' Turtle command. After that, the Turtle position
-- is tracked internally, but no points are added to the Track. A
-- new Track can be started by using the 'pd' command.
--
-- Example:
--
-- > program = drawingOf(pictures(fig) & solidRectangle(20,20))
-- >   where
-- >   fig = [ colored(thickPolyline(t,0.03),c)
-- >         | t <- tracks(turtleProgram)
-- >         | c <- repeating([red, purple, blue, green, orange, yellow])
-- >         ]
-- > 
-- >   turtleProgram = run(foreach([1..360], singleLine))
-- > 
-- >   singleLine(x) = run([pd, fd(x/100), lt(59), pu])
--
tracks :: TurtleCommand -> [Track]
tracks(cmd) = initialTurtle.#cmd.#saveTrace.#reversed

{- The example above in Python:

# Python program to draw  
# Rainbow Benzene 
# using Turtle Programming 
import turtle 
colors = ['red', 'purple', 'blue', 'green', 'orange', 'yellow'] 
t = turtle.Pen() 
turtle.bgcolor('black') 
for x in range(360): 
    t.pencolor(colors[x%6]) 
    t.width(x/100 + 1) 
    t.forward(x) 
    t.left(59) 

-}


-- | A list of all the partial tracks corresponding to the given command.
-- Useful to observe a step-by-step construction of the tracks.
--
-- Example:
--
-- > import Extras.Turtle
-- > import Extras.Cw(slideshow)
-- > 
-- > program = slideshow(foreach(slides,\s -> polylines(s)))
-- > 
-- > slides = partialTracks(turtleProgram)
-- > turtleProgram = repeat(7, [square, rt(360/7)])
-- > square = repeat(4, [fd(4), rt(90)])
--
-- The example above creates a slide show that illustrates the
-- construction of seven squares. It uses the function 'slideshow'
-- from the module "Extras.Cw"
--
partialTracks :: TurtleCommand -> [[Track]]
partialTracks(turtleProg) = foreach([2..sum(lengths)],partial)
  where
  fullTracks = tracks(turtleProg)
  fullLength = length(fullTracks)
  lengths = foreach(fullTracks,length)
  clengths = cumulativeSums(lengths)
  ctracks = zipped(clengths,fullTracks)
  partial(step)
    | n < fullLength = append(portion,taken)
    | otherwise = fullTracks
    where
    taken = selectedValues(ctracks,(<= step))
    n = length(taken)
    portion = first(fullTracks#(n+1),step - (0:clengths)#(n+1))

-- | Use this function to run Turtle programs that can use random numbers.
-- You need to provide an infinite list of numbers, where each of them
-- is between 0 (included) and 1 (excluded).
-- A simple way to use random numbers is with the
-- function 'randomDrawingOf' from the module "Cw".
--
-- Example 1:
--
-- > import Extras.Turtle
-- > import Extras.Cw(randomDrawingOf)
-- >
-- > program = randomDrawingOf(draw)
-- >   where
-- >   draw(random) = polylines(randomTracks(random,turtleProgram))
-- >   turtleProgram = repeat(50, [repeatRandom(100, randomLine), rt(180)])
-- >   randomLine = [fd(10),bk(9.8),rt(2)]
--
-- Example 2:
--
-- > program = randomDrawingOf(draw)
-- >   where
-- >   draw(random) = colored(sun,yellow)
-- >     where
-- >     sun = solidCircle(2) & polylines(randomTracks(random,turtleProgram))
-- >   turtleProgram = repeat(500, [ pu, home, randomized(seth,360), fd(2)
-- >                               , pd, randomized(fd,4)
-- >                               ])
--
randomTracks :: ([Number],TurtleCommand) -> [Track]
randomTracks(randoms,cmd) = turtle.#cmd.#saveTrace.#reversed
    where
    turtle = initialTurtle { rndNumbers = randoms }


trackInfo :: Track -> [(Point,Vector)]
trackInfo(points) = [ (a,vectorDifference(b,a)) 
                    | a <- points | b <- rest(points,1)
                    ]

-- | The length of the given Track
trackLength :: Track -> Number
trackLength(points) = sum(foreach(trackInfo(points),len))
    where
    len(_,dx) = vectorLength(dx)

-- | If @travel = alongTrack(points)@, then @travel@ is a function that can be
-- used to traverse a track traveling at 1 unit per second. The value
-- @travel(t)@ is a pair, where the first element is the location at time @t@
-- and the second element is the angle of the corresponding segment in
-- the given track.
--
-- Example:
--
-- > program = animationOf(movie)
-- >   where
-- >   movie(t) = placedAlong(turtleShape,travel(remainder(4*t,tlen))) 
-- >            & polyline(turtleTrack)
-- > 
-- >   placedAlong(pic,((x,y),a)) = translated(rotated(turtleShape,a),x,y)
-- >   travel = alongTrack(turtleTrack)
-- >   tlen = trackLength(turtleTrack)
-- > 
-- >   greenTurtle = colored(turtleShape, green)
-- >   turtleShape = rotated(thickPolygon(track(turtle),0.1),-90)
-- >   turtleTrack = track(run(figs(11, poly(7,18/7))))
-- >   figs(n,fig) = [repeat(n,[run(fig),lt(360/n)])]
-- >   poly(n,len) = figs(n,[fd(len)])
--
alongTrack :: Track -> Number -> (Point,Number)
alongTrack(points)
  | empty(tinfo) = \t -> ((0,0),0)
  | otherwise = go
  where
  tinfo = trackInfo(points)
  tlens = foreach(tinfo,\(_,dx) -> vectorLength(dx))
  lerp(t,(ax,ay),(bx,by)) = (ax + t * (bx - ax), ay + t * (by - ay))

  go(t) = if t <= 0 then let (x0,dx) = tinfo#1 in (x0,vectorDirection(dx))
          else whileloop((t,tlens,tinfo), cond, next, output)
    
  cond(t,ls,_) = nonEmpty(ls) && t >= ls#1
  next(t,ls,xds) = (t - ls#1, rest(ls,1), rest(xds,1))
  output(_,[],_) = go(0)
  output(t,ls,xds) = (lerp(t/ls#1,x0,x1),angle)
    where
    (x0,dx) = xds#1
    x1 = vectorSum(x0,dx)
    angle = vectorDirection(dx)

-------------------------------------------------------------------------------
-- Turtle Language
-------------------------------------------------------------------------------

-- | Move the Turtle forward by the given number of units
fd :: Number -> TurtleCommand
fd(len)(turtle) = turtle
  { position = position'
  , trace = turtle.#addPoint(position')
  }
  where
  position' = (px+len*hx,py+len*hy)
  (px,py) = turtle.#position
  (hx,hy) = turtle.#heading

-- | Move the Turtle backward by the given number of units
bk :: Number -> TurtleCommand
bk(len)(turtle) = turtle
  { position = position'
  , trace = turtle.#addPoint(position')
  }
  where
  position' = (px-len*hx,py-len*hy)
  (px,py) = turtle.#position
  (hx,hy) = turtle.#heading

-- | Turn the Turtle right (clockwise) by the given number of degrees
rt :: Number -> TurtleCommand
rt(angle)(turtle) = turtle
  { heading = rotatedPoint(turtle.#heading,-angle) }
  
-- | Turn the Turle left (counter-clockwise) by the given number of degrees
lt :: Number -> TurtleCommand
lt(angle)(turtle) = turtle
  { heading = rotatedPoint(turtle.#heading,angle) }

-- | Set the Turtle heading by first orienting it upright (pointing upwards)
--   and then rotating it clockwise by the given number of degrees
seth :: Number -> TurtleCommand
seth(angle)(turtle) = turtle
  { heading = rotatedPoint(homeHeading,-angle) }

-- | Move the Turtle to the absolute position given by the X and Y coordinates
setxy :: Point -> TurtleCommand
setxy(x,y)(turtle) = turtle
  { position = (x,y)
  , trace = turtle.#addPoint(x,y)
  }

-- | Move the Turtle to the center and set the heading to upright
home :: TurtleCommand
home(turtle) = turtle
  { heading = homeHeading
  , position = homePosition
  , trace = turtle.#addPoint(homePosition)
  }

-- | Pen Up: Stop tracing the positions of the Turtle.
-- If the pen was down, this command will end the current
-- 'Track'. Otherwise, the command is ignored.
pu :: TurtleCommand
pu(turtle) = case turtle.#pen of
  Pu -> turtle
  Pd -> turtle
          { trace = []
          , traces = turtle.#saveTrace
          , pen = Pu
          }

-- | Pen Down: Start tracing the positions of the Turtle.
-- If the pen was up, this command will start a new 'Track'.
-- Otherwise, the command is ignored.
pd :: TurtleCommand
pd(turtle) = case turtle.#pen of
  Pd -> turtle
  Pu -> turtle
          { trace = [turtle.#position]
          , pen = Pd
          }

-- Turtle Language Extensions

-- | Move the Turtle according to the given Point transformation
--
-- Example:
--
-- > turtleProgram :: TurtleProgram
-- > turtleProgram = [ pu, sethome(origin), fd(1), pd
-- >                 , repeat(6, [overxy(turn) ])
-- >                 , pu, fd(1), pd
-- >                 , turtle ]
-- > 
-- > turn(point) = rotatedPoint(point, 360/6)
--
-- The example above constructs a hexagon without
-- altering the heading of the turtle. It
-- also illustrates how you can mix Turtle commands
-- with other CodeWorld functions, such as
-- 'rotatedPoint'.
overxy :: (Point -> Point) -> TurtleCommand
overxy(f)(turtle) = turtle
  { position = p
  , trace = turtle.#addPoint(p)
  }
  where
  p = f(turtle.#position)

-- | Set the starting point for the trace to the given coordinates.
-- Any Track recorded before using this command will be discarded.
-- This command is only useful for initializaing your Turtle
-- program, so that it starts at a different position.
--
-- You can also use this command to move the Turtle before starting
-- tracing your tracks. For example, to start your Turtle with
-- the pen up, you can use the following pattern:
--
-- > turtleProgram :: TurtleProgram
-- > turtleProgram = [pu,sethome(origin)] ++ otherCommands
--
sethome :: Point -> TurtleCommand
sethome(x,y)(turtle) = turtle
  { position = (x,y)
  , trace = case turtle.#pen of
                Pu -> []
                Pd -> [(x,y)]
  }

-- | The origin is at the center of the output window
origin :: Point
origin = homePosition

-- | A simple drawing of a Turtle that can be used to observe
-- its current position and heading.
turtle :: TurtleCommand
turtle = run([ rt(150), fd(0.2), lt(120), fd(0.2), lt(60), fd(0.4), lt(120)
             , fd(0.4), lt(60), fd(0.2), lt(120), fd(0.2), lt(30)
             ])

-- | @randomized(cmd,maxnum)@ can be used to run one of the following
-- Turtle commands: 'fd', 'bk', 'rt', 'lt', 'seth', or with a custom command
-- that takes a Number as the argument, so that the command is run
-- with a random number between 0 (included) and maxnum (excluded).
-- If this function is used inside 'tracks' instead of inside 'randomTracks',
-- the value @maxnum/2@ will be passed to @cmd@ instead of a random number.
--
-- Example:
--
-- > program = randomDrawingOf(draw)
-- >   where
-- >   draw(random) = pictures([ colored(thickPolyline(t,0.25),c)
-- >                           | t <- randomTracks(random1,turtleProgram)
-- >                           | c <- random2
-- >                           ])
-- >         where
-- >         random1 = randomNumbers(random#1)
-- >         random2 = [ RGB(r,g,b) 
-- >                   | [r,g,b] <- groups(randomNumbers(random#2),3)
-- >                   ]
-- >     
-- >   turtleProgram = repeat(10, [pd,makeTrack,pu,home])
-- >   makeTrack = repeat(100, [ randomized(\r -> fd(2*r-1), 1.5)
-- >                           , randomized(\r -> rt(90*truncation(r)), 4)
-- >                           ])
--
randomized :: (Number -> TurtleCommand,Number) -> TurtleCommand
randomized(cmd,maxnum)(turtleOld) = cmd(num)(turtleNew)
    where
    turtleNew = turtleOld { rndNumbers = rest(turtleOld.#rndNumbers,1) }
    num = maxnum * rnd
    rnd | empty(turtleOld.#rndNumbers) = 0.5
        | otherwise = turtleOld.#rndNumbers#1

-- | Repeat a turtle Program a random number of times up to the given
-- maximum. This is a specialized version of 'randomized'.
repeatRandom :: (Number,TurtleProgram) -> TurtleCommand
repeatRandom(maxnum,prog) = randomized(\r -> repeat(r,prog),maxnum)

-- Drawing API Extensions

-- | Draw each Track in a list of tracks as a polyline.
polylines :: [Track] -> Picture
polylines(ls) = ls.$polyline.#pictures

-- | Draw each Track in a list of tracks as a thick polyline
-- of the given thickness.
thickPolylines :: ([Track],Number) -> Picture
thickPolylines(ls,t) = pictures(foreach(ls,\l -> thickPolyline(l,t)))

-- | Draw each Track in a list of tracks as a solid polygon.
solidPolygons :: [Track] -> Picture
solidPolygons(ls) = ls.$solidPolygon.#pictures

-- | Draw all the points in all the polylines of a list of tracks.
dottylines :: [Track] -> Picture
dottylines(ls) = ls.$dottyline.#pictures

-- | Draw the vertices of a polyline as dots
dottyline :: [Point] -> Picture
dottyline(pts) = pts.$makeDot.#pictures
  where
  makeDot(x,y) = translated(solidCircle(0.05),x,y)

-------------------------------------------------------------------------------
-- Turtle Aux
-------------------------------------------------------------------------------

addPoint :: Point -> Turtle -> [Point]
addPoint(p)(turtle) = case turtle.#pen of
  Pu -> turtle.#trace
  Pd -> p : turtle.#trace

saveTrace :: Turtle -> [[Point]]
saveTrace(turtle) = case turtle.#trace of
  [] -> turtle.#traces
  pts -> reversed(pts) : turtle.#traces
            

-------------------------------------------------------------------------------
-- Examples
-------------------------------------------------------------------------------

{-
turtleExample1 = (stars.#run.#tracks.#polylines & anchors.#polyline).#drawingOf
  where
  noStar(l) = run([pu,star(l),pd])
  star(l) = run([repeat(8,[fd(l/30),rt(135)]),pu,fd(3*l/30),rt(57),pd])
  tracedStar(l) = run([star(l),pu,fd(3*l/30),rt(57),pd])
  stars = foreach( [0,4..120], star)
  anchors = foreach([0,4..120], noStar).#run.#tracks.#concatenation
-}


randomExample = randomDrawingOf(draw)
  where
  draw(random) = polyline(track(prog(random)))
  prog(random) = run(foreach(first(random,50), prog1))
  prog1(r) = run([ prog2(randomNumbers(r)), rt(180) ])
  prog2(random) = repeat(truncation(100*random#1), [fd(10),bk(9.8),rt(2)])
  

-- | The first example is based on the following code:
--
-- >   program = drawingOf(polylines(tracks(turtleProgram)))
-- >   turtleProgram = run(figs(14, poly(7,2)))
-- >   figs(n,fig) = [repeat(n,[run(fig),lt(360/n)])]
-- >   poly(n,len) = figs(n,[fd(len)])
--
-- Note how normal CodeWorld functions are integrated with the turtle
-- commands, even in the presence of recursion.
--
-- The rest of the examples are taken
-- from the Logo 15-word challenge at
-- <http://www.mathcats.com/gallery/15wordcontest.html>
--
-- The keywords before each name show information about how many 'repeat'
-- statements each example used, whether it used advanced control functions,
-- such as 'foreach' or 'forloop', and whether advanced math functions, such
-- as trig functions or logarithms were used to define the shape. You can
-- use this information to estimate the relative complexity of the shapes.
--
-- Here are the codes for the examples:
--
-- >   ring = let fd'(x) = fd(x/20)
-- >              bk'(x) = bk(x/20)
-- >          in sethome(4,0)
-- >             : [repeat(16, [ fd'(85), lt(60), fd'(107)
-- >                           , bk'(72), lt(53), fd'(74)])]
-- >   
-- >   blade = let fd'(x) = fd(x/20)
-- >               bk'(x) = bk(x/20)
-- >           in sethome(-3,-4)
-- >              : [repeat(36,[fd'(60),rt(61),bk'(80),lt(41),fd'(85),rt(41)])]
-- > 
-- >   hypercube = sethome(-3.5,1.5)
-- >     : [repeat(8,[repeat(4,[rt(90),fd(3)]),bk(3),lt(45)])]
-- >   
-- >   star1 = sethome(-2.5,-3.5)
-- >     : [repeat(18,[repeat(5,[rt(40),fd(10),rt(120)]),rt(20)])]
-- > 
-- >   fanflower = sethome(-1.5,5)
-- >               : [repeat(12,[repeat(75,[fd(4),bk(4),rt(2)]),fd(10)])]
-- > 
-- >   jagged1 = sethome(0,-6) 
-- >     : [repeat(4,[repeat(30,[lt(90),fd(0.2),rt(90),fd(0.2)]),rt(90)])]
-- > 
-- >   jagged2 = sethome(4,-6)
-- >     : [repeat(4,[repeat(20,[lt(160),fd(1.5),rt(160),fd(1.5)]),rt(90)])]
-- > 
-- >   jagged3 = sethome(2.5,-7) : lt(5)
-- >     : [repeat(8,[repeat(20,[lt(170),fd(1.5),rt(170),fd(1.5)]),rt(45)])]
-- >     
-- >   pentahexa = sethome(-0.5,-2)
-- >     : [repeat(5,[repeat(6,[fd(4),lt(72)]),lt(144)])]
-- > 
-- >   leaves(n) = -- Useful values for n: 1 to 7
-- >     sethome(-2.7,-1.2)
-- >     : [repeat(8,[rt(45),repeat(n,[repeat(90,[fd(0.1),rt(2)]),rt(90)])])]
-- >   
-- >   roses(l,n,k) = foreach([1..360*n],\i -> run([fd(l/10),rt(i+x)]))
-- >     where
-- >     x = (2*k - n) / (2*n)
-- >     -- Useful values:
-- >     -- roses 5 5 3
-- >     -- roses 5 7 3
-- >     -- roses 5 10 7
-- >     -- roses 5 12 5 
-- > 
-- >   bullring = sethome(-3,-0.5)
-- >     : foreach([0..1002],\i -> run([fd(0.4),seth(360*i^3 / 1002)]))
-- >     
-- >   squareSpiral = foreach([1..800],\i -> run([fd(i/40),rt(89)]))
-- > 
-- >   diaphragm = foreach([1..100],\i -> let fd'(x) = fd(x/20)
-- >     in run([fd'(5+i),rt(45),fd'(10+i),rt(60)]))
-- >   
-- >   octagons =
-- >     foreach( [1..15]
-- >        , \i -> repeat(5, [repeat(8, [fd (0.4 + i*0.2), rt(45)]), rt(72)])
-- >        )
-- >     
-- >   circleSpiral = foreach([0,0.05..4],\i -> repeat(180,[fd(i/10),rt(1)]))
-- >   
-- >   pentaStarSpiral =
-- >     foreach( [0,3..96]
-- >            , \l -> run([repeat(5,[fd(l/20),rt(144)]),fd(l/20),rt(30)]))
-- >   
-- >   octaStarSpiral =
-- >     foreach( [0,4..120],
-- >        \l -> run([repeat(8,[fd(l/30),rt(135)]),pu,fd(2*l/30),rt(30),pd]))
-- > 
-- >   sqcirc1 =
-- >     foreach( [1..36],
-- >        \i -> run([repeat(36,[fd(0.5),rt(10)]),fd(i/20),rt(90),fd(i/20)]))
-- >   
-- >   pentapenta =
-- >     foreach([10,9..1],\i -> repeat(5,[repeat(5,[fd(i/2),lt(72)]),lt(72)]))
-- >   
-- >   hexagon2 = foreach( [100,95..10]
-- >                 , \i -> repeat(6,[repeat(6,[fd(i/20),lt(60)]),lt(60)]))
-- > 
-- >   hexagon1 = foreach( [100,50..50]
-- >                 , \i -> repeat(6,[repeat(6,[fd(i/20),lt(60)]),lt(60)]))
-- > 
-- >   jaggystar = fd(-6.5) 
-- >             : foreach([0..2200],\i -> run([fd(0.75*sin(i)), rt(i^2)]))
-- > 
-- >   fish1 = foreach([1..360],\t -> run(cmds(t)))
-- >     where
-- >     cmds(t) = [ overxy(\(x,y) -> (8*cos(2*t),y))
-- >               , overxy(\(x,y) -> (x,x*cos(t)))
-- >               , home
-- >               ]
-- >   
-- >   fish2 = foreach([-315..315],\t -> setxy(t*sin(t)/50,0.5*t*cos(2*t)/50))
-- >   
-- >   gillyflower =
-- >     foreach( [1..450]
-- >            , \i -> let a = 73 * sin(i) in run([fd(a/20),rt(88*cos(a))]))
-- >   
-- >   petals(n) = foreach([0..180],\t -> run([seth(t),fd(10*sin(t*n)),home]))
-- > 
-- >   eye = foreach([1..1800],\i -> run([fd(log(i)/10),bk(sin(i)),rt(10)]))
-- > 
-- >   spirotunnel =
-- >     forloop( 1,(<= 160),\i -> i + sin(i)
-- >            , \i -> run([fd(i/80),bk(i/10),rt(51)])
-- >            )
-- >                      
-- >   neutronStar =
-- >     forloop(1,(<= 4),\i -> i + sin(i+7)/2
-- >            ,\i -> let a = 2*i
-- >                   in run([fd(a),bk(a),rt(41)]))
-- > 
--
turtleExamples :: Program
turtleExamples =
  (slides.$make ++ [bullring.#run.#tracks.#dottylines]).#slideshow
  where
  make(i,l,s) = blank
    & translated(lettering(i <> ": " <> l),0,9.5) 
    & translated(colored(solidRectangle(10,1.2),white),0,9.5)
    & s.#run.#tracks.#polylines

  slides =
    [ ("recursive", "figs(14, poly(7,2))",figs(14, poly(7,2)))
    , ("rep 1", "ring",ring)
    , ("rep 1", "blade",blade)
    , ("rep 2", "hypercube",hypercube)
    , ("rep 2", "star1",star1)
    , ("rep 2", "fanflower",fanflower)
    , ("rep 2", "jagged1",jagged1)
    , ("rep 2", "jagged2",jagged2)
    , ("rep 2", "jagged3",jagged3)
    , ("rep 2", "pentahexa",pentahexa)
    , ("rep 3", "leaves(3)",leaves(3))
    , ("rep 3", "leaves(7)",leaves(7))
    , ("foreach", "roses(5,5,3)",roses(5,5,3))
    , ("foreach", "roses(5,12,5)",roses(5,12,5))
    , ("foreach", "bullring",bullring)
    , ("foreach", "squareSpiral",squareSpiral)
    , ("foreach", "diaphragm",diaphragm)
    , ("foreach+rep 1", "octagons",octagons)
    , ("foreach+rep 1", "circleSpiral",circleSpiral)
    , ("foreach+rep 1", "pentaStarSpiral",pentaStarSpiral)
    , ("foreach+rep 1", "octaStarSpiral",octaStarSpiral)
    , ("foreach+rep 1", "sqcirc1",sqcirc1)
    , ("foreach+rep 2", "pentapenta",pentapenta)
    , ("foreach+rep 2", "hexagon2",hexagon2)
    , ("foreach+rep 2", "hexagon1",hexagon1)
    , ("foreach+trig", "jaggystar",jaggystar)
    , ("foreach+trig", "fish1",fish1)
    , ("foreach+trig", "fish2",fish2)
    , ("foreach+trig", "gillyflower",gillyflower)
    , ("foreach+trig", "petals(7)",petals(7))
    , ("foreach+trig+log", "eye",eye)
    , ("forloop+trig", "spirotunnel",spirotunnel)
    , ("forloop+trig", "neutronStar",neutronStar)
    ]

  test = [repeat(8,[clover,rt(45)])]
    where
    n = 3
    base = repeat(90,[fd(0.1),rt(2)])
    clover = repeat(n,[base,rt(90)])
  
  figs(n,fig) = [repeat(n,[run(fig),lt(360/n)])]
  poly(n,len) = figs(n,[fd(len)])

---
--- Codes for examples
---

  ring = let fd'(x) = fd(x/20)
             bk'(x) = bk(x/20)
         in sethome(4,0)
            : [repeat(16,[fd'(85),lt(60),fd'(107),bk'(72),lt(53),fd'(74)])]
  
  blade = let fd'(x) = fd(x/20)
              bk'(x) = bk(x/20)
          in sethome(-3,-4)
             : [repeat(36,[fd'(60),rt(61),bk'(80),lt(41),fd'(85),rt(41)])]

  hypercube = sethome(-3.5,1.5)
    : [repeat(8,[repeat(4,[rt(90),fd(3)]),bk(3),lt(45)])]
  
  star1 = sethome(-2.5,-3.5)
    : [repeat(18,[repeat(5,[rt(40),fd(10),rt(120)]),rt(20)])]

  fanflower = sethome(-1.5,5)
              : [repeat(12,[repeat(75,[fd(4),bk(4),rt(2)]),fd(10)])]

  jagged1 = sethome(0,-6) 
    : [repeat(4,[repeat(30,[lt(90),fd(0.2),rt(90),fd(0.2)]),rt(90)])]

  jagged2 = sethome(4,-6)
    : [repeat(4,[repeat(20,[lt(160),fd(1.5),rt(160),fd(1.5)]),rt(90)])]

  jagged3 = sethome(2.5,-7) : lt(5)
    : [repeat(8,[repeat(20,[lt(170),fd(1.5),rt(170),fd(1.5)]),rt(45)])]
    
  pentahexa = sethome(-0.5,-2)
    : [repeat(5,[repeat(6,[fd(4),lt(72)]),lt(144)])]

  leaves(n) = -- Useful values for n: 1 to 7
    sethome(-2.7,-1.2)
    : [repeat(8,[rt(45),repeat(n,[repeat(90,[fd(0.1),rt(2)]),rt(90)])])]
  
  roses(l,n,k) = foreach([1..360*n],\i -> run([fd(l/10),rt(i+x)]))
    where
    x = (2*k - n) / (2*n)
    -- Useful values:
    -- roses 5 5 3
    -- roses 5 7 3
    -- roses 5 10 7
    -- roses 5 12 5 

  bullring = sethome(-3,-0.5)
    : foreach([0..1002],\i -> run([fd(0.4),seth(360*i^3 / 1002)]))
    
  squareSpiral = foreach([1..800],\i -> run([fd(i/40),rt(89)]))

  diaphragm = foreach([1..100],\i -> let fd'(x) = fd(x/20)
    in run([fd'(5+i),rt(45),fd'(10+i),rt(60)]))
  
  octagons =
    foreach( [1..15]
       , \i -> repeat(5, [repeat(8, [fd (0.4 + i*0.2), rt(45)]), rt(72)])
       )
    
  circleSpiral = foreach([0,0.05..4],\i -> repeat(180,[fd(i/10),rt(1)]))
  
  pentaStarSpiral =
    foreach( [0,3..96]
           , \l -> run([repeat(5,[fd(l/20),rt(144)]),fd(l/20),rt(30)]))
  
  octaStarSpiral =
    foreach( [0,4..120]
       , \l -> run([repeat(8,[fd(l/30),rt(135)]),pu,fd(2*l/30),rt(30),pd]))

  sqcirc1 =
    foreach( [1..36]
       , \i -> run([repeat(36,[fd(0.5),rt(10)]),fd(i/20),rt(90),fd(i/20)]))
  
  pentapenta =
    foreach([10,9..1],\i -> repeat(5,[repeat(5,[fd(i/2),lt(72)]),lt(72)]))
  
  hexagon2 = foreach( [100,95..10]
                , \i -> repeat(6,[repeat(6,[fd(i/20),lt(60)]),lt(60)]))

  hexagon1 = foreach( [100,50..50]
                , \i -> repeat(6,[repeat(6,[fd(i/20),lt(60)]),lt(60)]))

  jaggystar = fd(-6.5) 
            : foreach([0..2200],\i -> run([fd(0.75*sin(i)), rt(i^2)]))

  fish1 = foreach([1..360],\t -> run(cmds(t)))
    where
    cmds(t) = [ overxy(\(x,y) -> (8*cos(2*t),y))
              , overxy(\(x,y) -> (x,x*cos(t)))
              , home
              ]
  
  fish2 = foreach([-315..315],\t -> setxy(t*sin(t)/50,0.5*t*cos(2*t)/50))
  
  gillyflower =
    foreach( [1..450]
           , \i -> let a = 73 * sin(i) in run([fd(a/20),rt(88*cos(a))]))
  
  petals(n) = foreach([0..180],\t -> run([seth(t),fd(10*sin(t*n)),home]))

  eye = foreach([1..1800],\i -> run([fd(log(i)/10),bk(sin(i)),rt(10)]))

  spirotunnel =
    forloop( 1,(<= 160),\i -> i + sin(i)
           , \i -> run([fd(i/80),bk(i/10),rt(51)])
           )
                     
  neutronStar =
    forloop(1,(<= 4),\i -> i + sin(i+7)/2
           ,\i -> let a = 2*i
                  in run([fd(a),bk(a),rt(41)]))
