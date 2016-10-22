{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

import CodeWorld.Message

import Data.Char (isPunctuation, isSpace)
import Data.Monoid ((<>), mappend)
import Data.Text (Text)
import Control.Exception (finally)
import Control.Monad (forM_, forever, when)
import Control.Concurrent (MVar, newMVar, modifyMVar_, modifyMVar, readMVar)
import Data.Time.Clock
import Data.Time.Calendar
import Data.Scientific
import Data.UUID
import Data.UUID.V4
import qualified Data.Text as T
import qualified Data.Text.IO as T
import qualified Network.WebSockets as WS
import qualified Data.ByteString.Lazy as BS
import GHC.Generics

import Data.Aeson
import Data.Aeson.Types
import qualified Data.HashMap.Strict as HM

{-

Protocol:

Create a new game, join it as player 0 and waits for n players in total.
Returns an id for the new game.
→ newgame <username> <n>
← gameid <id>

Joins an existing game. Returns the player id.
→ joingame <id>
← joined <n>

Server tells the clients about the number of connected players
← players <n>

Server tells the clients that the game has started
← started

Client sends an input event
→ event <e>

Server sends input event to all players, with a player id and timestamp (seconds)
← event <n> <timestamp> <e>

Server indicates to the client that some other player dropped. Closes the connection.
← aborted

-}

-- Server state

data Game = Waiting { numPlayers :: Int
                    , players :: [WS.Connection]
                    }
          | Running { players :: [WS.Connection] }

type ServerState = HM.HashMap GameId Game

-- Server state manipulation

newServerState :: ServerState
newServerState = HM.empty

newGame :: WS.Connection -> GameId -> Int -> ServerState -> ServerState
newGame conn gid playerCount = HM.insert gid (Waiting playerCount [conn])

joinGame :: WS.Connection -> GameId -> ServerState -> (ServerState, Maybe PlayerId)
joinGame conn gameid games =
    case HM.lookup gameid games of
        Just (Waiting pc plys) | length plys < pc ->
                let pid = length plys
                    game' = Waiting pc (conn : plys)
                    games' = HM.insert gameid game' games
                in (games', Just pid)
        _ -> (games, Nothing)


tryStartGame :: GameId -> ServerState -> (ServerState, Bool)
tryStartGame gameid games =
    case HM.lookup gameid games of
        Just (Waiting pc plys) | length plys == pc ->
                let game' = Running plys
                    games' = HM.insert gameid game' games
                in (games', True)
        _ -> (games, False)

getPlayers :: GameId -> ServerState -> [WS.Connection]
getPlayers gameid games =
    case HM.lookup gameid games of
        Just game -> players game
        Nothing   -> []

dropGame :: GameId -> ServerState -> ServerState
dropGame gameid games = HM.delete gameid games

-- Communication

getTimeStamp :: IO Scientific
getTimeStamp = do
    now <- getCurrentTime
    let diff = now `diffUTCTime` UTCTime (ModifiedJulianDay 0) 0
    return $ realToFrac $ diff

broadcast :: ServerMessage -> GameId -> ServerState -> IO ()
broadcast msg = broadcastBS (encode msg)

broadcastBS :: BS.ByteString -> GameId -> ServerState -> IO ()
broadcastBS message gameid games = do
    forM_ (getPlayers gameid games) $ \conn -> WS.sendTextData conn message

{-
broadcast :: BS.ByteString -> ServerState -> IO ()
broadcast message (id, clients) = do
    case decode message of
        Just val -> do
            time <- getTimeStamp
            let val' = HM.insert "timestamp" (toJSON time) $
                       HM.insert "player" (toJSON id) $
                       val
            T.putStrLn $ "Sending a message from client " <> T.pack (show id) <> ": " <> T.pack (show (val'::Object))
            forM_ clients $ \(_, conn) -> WS.sendTextData conn (encode val')
        Nothing ->
            T.putStrLn $ "Ignoring unparsable message."
-}

main :: IO ()
main = do
    state <- newMVar newServerState
    WS.runServer "0.0.0.0" 9160 $ application state

application :: MVar ServerState -> WS.ServerApp
application state pending = do
    conn <- WS.acceptRequest pending
    WS.forkPingThread conn 30
    welcome conn state

getClientMessage :: WS.Connection -> IO ClientMessage
getClientMessage conn = do
    msg <- WS.receiveData conn
    case decode msg of
        Just msg -> return msg
        Nothing -> fail "Invalid client message"

welcome :: WS.Connection -> MVar ServerState -> IO ()
welcome conn state = do
    msg <- getClientMessage conn
    case msg of NewGame n ->    welcomeNew conn state n
                JoinGame gid -> welcomeJoin conn state gid

welcomeNew :: WS.Connection -> MVar ServerState -> Int -> IO ()
welcomeNew conn state n = do
    gid <- nextRandom
    modifyMVar_ state (return . newGame conn gid n)
    announcePlayers gid state
    talk 0 conn gid state

welcomeJoin :: WS.Connection -> MVar ServerState -> GameId -> IO ()
welcomeJoin conn state gid = do
    Just pid <- modifyMVar state (return . joinGame conn gid)
    announcePlayers gid state
    talk pid conn gid state

announcePlayers gid state = do
    n <- length . getPlayers gid  <$> readMVar state
    readMVar state >>= broadcast (PlayersWaiting n) gid

    started <- modifyMVar state (return . tryStartGame gid)
    when started $ do
        time <- getTimeStamp
        readMVar state >>= broadcast (Started time) gid

talk ::  PlayerId -> WS.Connection -> GameId -> MVar ServerState ->  IO ()
talk pid conn gid state = forever $ do
    InEvent e <- getClientMessage conn
    time <- getTimeStamp
    readMVar state >>= broadcast (OutEvent time pid e) gid
