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
using System.Xml.Linq;
using PDGBoardGames;

namespace HamQuestEngine
{
    public class DefaultRandomNumberGenerator
    {
        public static IRandomNumberGenerator LoadFromNode(XElement node)
        {
            return new RandomNumberGenerator();
        }
    }
}
