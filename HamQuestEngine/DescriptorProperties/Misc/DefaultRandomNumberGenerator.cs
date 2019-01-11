using System;
using System.Net;
using System.Windows;



using System.Windows.Input;



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
