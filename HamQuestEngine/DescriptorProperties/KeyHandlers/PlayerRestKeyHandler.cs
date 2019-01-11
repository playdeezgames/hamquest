using System.Xml.Linq;
using System.Windows;
using System.Windows.Input;

namespace HamQuestEngine
{
    public class PlayerRestKeyHandler:IPlayerKeyHandler
    {
        public static IPlayerKeyHandler LoadFromNode(XElement node)
        {
            return new PlayerRestKeyHandler();
        }


        public bool HandleKey(Key key, Descriptor descriptor)
        {
            if (key == Key.Space)
            {
                PlayerDescriptor playerDescriptor = descriptor as PlayerDescriptor;
                if (playerDescriptor != null)
                {
                    if (playerDescriptor.MapCreature.Map.HasCreature)
                    {
                        playerDescriptor.MessageQueue.AddMessage(playerDescriptor.GetProperty<string>(GameConstants.Properties.CannotRestMessage));
                    }
                    else
                    {
                        //rest message
                        playerDescriptor.MessageQueue.AddMessage(playerDescriptor.GetProperty<string>(GameConstants.Properties.RestMessage));
                        //heal wound if any
                        if (playerDescriptor.MapCreature.Wounds > 0)
                        {
                            playerDescriptor.MapCreature.Wounds--;
                        }
                        //run out the rest of the turn
                        int steps = playerDescriptor.GetProperty<PlayerStepTracker>(GameConstants.Properties.StepTracker).Total - playerDescriptor.GetProperty<PlayerStepTracker>(GameConstants.Properties.StepTracker).Steps;
                        while (steps > 0)
                        {
                            playerDescriptor.Step();
                            steps--;
                        }
                        //check for wandering monster, add to visit count
                        playerDescriptor.Maze[playerDescriptor.MazeColumn][playerDescriptor.MazeRow].CellInfo.AddVisit();
                    }
                    return true;
                }
            }
            return false;
        }
    }
}
