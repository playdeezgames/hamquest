
namespace PDGBoardGames
{
    public class MazePortalBase
    {
        public bool Open { get; set; }
        public virtual void Clear()
        {
            Open = false;
        }
        public MazePortalBase()
        {
            Open = false;
        }
    }
}
