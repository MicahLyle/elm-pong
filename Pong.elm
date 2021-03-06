-- See this document for more information on making Pong:
-- http://elm-lang.org/blog/Pong.elm
import Color exposing (..)
import Collage exposing (..)
import Element exposing (..)
import Text 
import Char 
import Time exposing (..)
import Window 
import Html exposing (..)
import Keyboard exposing (..)
import Set exposing (Set)
import Task
import AnimationFrame

main = program { init = (initialGame, initialSizeCmd)
               , view = view
               , update = update
               , subscriptions = subscriptions 
               }

-- KeyDown/KeyUp/keysDown technique taken from this answer : 
--     http://stackoverflow.com/a/39127092/509928
-- 
-- to this question : 
--     http://stackoverflow.com/questions/39125989/keyboard-combinations-in-elm-0-17-and-later
-- 

type Msg = KeyDown KeyCode
         | KeyUp KeyCode
         | WindowResize (Int,Int)
         | Tick Float
         | NoOp

getInput : Game -> Float -> Input
getInput game delta 
         = { space = Set.member (Char.toCode ' ') (game.keysDown)
           , reset = Set.member (Char.toCode 'R') (game.keysDown)
           , pause = Set.member (Char.toCode 'P') (game.keysDown)
           , dir = if Set.member 38 (game.keysDown) then 1 -- down arrow
                   else if Set.member 40 (game.keysDown) then -1 -- up arrow
                   else 0
           , delta = inSeconds delta
           }

update msg game =
  case msg of
    KeyDown key ->
      ({ game | keysDown = Set.insert key game.keysDown }, Cmd.none)
    KeyUp key ->
      ({ game | keysDown = Set.remove key game.keysDown }, Cmd.none)
    Tick delta ->
      let input = getInput game delta
      in (updateGame input game, Cmd.none)
    WindowResize dim ->
      ({game | windowDimensions = dim}, Cmd.none)
    NoOp ->
      (game, Cmd.none)

subscriptions _ =
    Sub.batch
        [ Keyboard.downs KeyDown
        , Keyboard.ups KeyUp
        , Window.resizes sizeToMsg
        , AnimationFrame.diffs Tick
        ]

-- initialSizeCmd/sizeToMsg technique taken from this answer : 
--     https://www.reddit.com/r/elm/comments/4jfo32/getting_the_initial_window_dimensions/d369kw1/
--
-- to this question : 
--     https://www.reddit.com/r/elm/comments/4jfo32/getting_the_initial_window_dimensions/

initialSizeCmd : Cmd Msg
initialSizeCmd =
  Task.perform sizeToMsg (Window.size)

sizeToMsg : Window.Size -> Msg
sizeToMsg size =
  WindowResize (size.width, size.height)

-- MODEL

(gameWidth, gameHeight) = (600, 400)
(halfWidth, halfHeight) = (gameWidth / 2, gameHeight / 2)

type State = Play | Pause

type alias Ball = {
    x: Float,
    y: Float,
    vx: Float,
    vy: Float
}

type alias Player = {
    x: Float,
    y: Float,
    vx: Float,
    vy: Float,
    score: Int
}

type alias Game =
  { keysDown : Set KeyCode,
    windowDimensions : (Int, Int),
    state: State,
    ball: Ball,
    player1: Player,
    player2: Player
  }

player : Float -> Player
player initialX =
  { x = initialX
  , y = 0
  , vx = 0
  , vy = 0
  , score = 0
  }

initialBall = { x = 0, y = 0, vx = 200, vy = 200 }

initialPlayer1 = player (20 - halfWidth)

initialPlayer2 = player (halfWidth - 20)

initialGame =
  { keysDown = Set.empty
  , windowDimensions = (0,0)
  , state   = Pause
  , ball    = initialBall
  , player1 = initialPlayer1
  , player2 = initialPlayer2
  }

type alias Input = {
    space : Bool,
    reset : Bool,
    pause : Bool,
    dir : Int,
    delta : Time
}

-- UPDATE

updateGame : Input -> Game -> Game
updateGame {space, reset, pause, dir, delta} ({state, ball, player1, player2} as game) =
  let score1 = if ball.x >  halfWidth then 1 else 0
      score2 = if ball.x < -halfWidth then 1 else 0

      newState =
        if  space then Play 
        else if (pause) then Pause 
        else if (score1 /= score2) then Pause 
        else state

      newBall =
        if state == Pause
            then ball
            else updateBall delta ball player1 player2

  in
      if reset
         then { game | state   = Pause
                     , ball    = initialBall
                     , player1 = initialPlayer1 
                     , player2 = initialPlayer2
              }

         else { game | state   = newState
                     , ball    = newBall
                     , player1 = updatePlayer delta dir score1 player1
                     , player2 = updateComputer newBall score2 player2
              }

updateBall : Time -> Ball -> Player -> Player -> Ball
updateBall t ({x, y, vx, vy} as ball) p1 p2 =
  if not (ball.x |> near 0 halfWidth)
    then { ball | x = 0, y = 0 }
    else physicsUpdate t
            { ball |
                vx = stepV vx (within ball p1) (within ball p2),
                vy = stepV vy (y < 7-halfHeight) (y > halfHeight-7)
            }


updatePlayer : Time -> Int -> Int -> Player -> Player
updatePlayer t dir points player =
  let player1 = physicsUpdate  t { player | vy = toFloat dir * 200 }
  in
      { player1 |
          y = clamp (22 - halfHeight) (halfHeight - 22) player1.y,
          score = player.score + points
      }

updateComputer : Ball -> Int -> Player -> Player
updateComputer ball points player =
    { player |
        y = clamp (22 - halfHeight) (halfHeight - 22) ball.y,
        score = player.score + points
    }

physicsUpdate t ({x, y, vx, vy} as obj) =
  { obj |
      x = x + vx * t,
      y = y + vy * t
  }

near : Float -> Float -> Float -> Bool
near k c n =
    n >= k-c && n <= k+c

within ball paddle =
    near paddle.x 8 ball.x && near paddle.y 20 ball.y


stepV v lowerCollision upperCollision =
  if lowerCollision then abs v
  else if upperCollision then 0 - abs v
  else v

-- VIEW

view : Game -> Html Msg
view {windowDimensions, state, ball, player1, player2} =
  let scores : Element
      scores = txt (Text.height 50) (toString player1.score ++ "  " ++ toString player2.score)
      (w,h) = windowDimensions
  in
      toHtml <|
      container w h middle <|
      collage gameWidth gameHeight
        [ rect gameWidth gameHeight
            |> filled pongGreen
        , verticalLine gameHeight
            |> traced (dashed red)
        , oval 15 15
            |> make ball
        , rect 10 40
            |> make player1
        , rect 10 40
            |> make player2
        , toForm scores
            |> move (0, gameHeight/2 - 40)
        , toForm (statusMessage state)
            |> move (0, 40 - gameHeight/2)
        ]

statusMessage state =
    case state of
        Play    -> txt identity ""
        Pause   -> txt identity pauseMessage

verticalLine height =
     path [(0, height), (0, -height)]

pongGreen = rgb 60 100 60
textGreen = rgb 160 200 160
txt f = Text.fromString >> Text.color textGreen >> Text.monospace >> f >> leftAligned
pauseMessage = "SPACE to start, P to pause, R to reset, WS and &uarr;&darr; to move"

make obj shape =
    shape
      |> filled white
      |> move (obj.x,obj.y)

