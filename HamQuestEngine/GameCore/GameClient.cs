
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
