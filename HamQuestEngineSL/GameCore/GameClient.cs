using System;
using System.Net;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using System.Windows.Ink;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Shapes;

namespace HamQuestEngine
{
    public interface IGameClient
    {
        Game Game { get; }
    }
    public abstract class GameClientBase:IGameClient
    {
        private Game game;
        public Game Game
        {
            get
            {
                return game;
            }
        }
        public GameClientBase(Game theGame)
        {
            game = theGame;
        }
    }
}
