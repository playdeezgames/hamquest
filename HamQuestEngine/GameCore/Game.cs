using PDGBoardGames;

namespace HamQuestEngine
{
    public class Game
    {
        public IRandomNumberGenerator RandomNumberGenerator
        {
            get
            {
                return TableSet.PropertyGroupTable.GetPropertyDescriptor(GameConstants.PropertyGroups.GameConfiguration).GetProperty<IRandomNumberGenerator>(GameConstants.Properties.RandomNumberGenerator);
            }
        }
        private TableSet tableSet;
        public TableSet TableSet
        {
            get
            {
                return tableSet;
            }
        }
        private Maze maze;
        public Maze Maze
        {
            get
            {
                return maze;
            }
        }
        private MessageQueue messageQueue = null;
        public MessageQueue MessageQueue
        {
            get
            {
                if (messageQueue == null)
                {
                    messageQueue = new MessageQueue(5, this);
                }
                return messageQueue;
            }
        }
        public Game()
        {
        }
        public void Initialize()
        {
            tableSet = new TableSet(new CreatureTable(), new MessageTable(),new PropertyGroupTable(),new TerrainTable(),new ItemTable());
            tableSet.CreatureTable.Reset();
            maze = new Maze(this);
            maze.Generate(RandomNumberGenerator);
            maze.PlayerDescriptor.Initialize();
        }
    }
}
