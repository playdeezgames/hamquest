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

namespace PDGBoardGames
{
    public class RandomNumberGenerator:IRandomNumberGenerator
    {
        private Random random = new Random();
        public Int32 Next(Int32 maximum)
        {
            return random.Next(maximum);
        }
        public Int32 Next(Int32 minimum, Int32 maximum)
        {
            return random.Next(minimum, maximum);
        }

    }
}
