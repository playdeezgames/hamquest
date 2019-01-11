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
    public interface IRoller
    {
        int Roll(Descriptor theDescriptor,Game theGame);
        int GetMaximumRoll(Descriptor theDescriptor, Game theGame);
        int GetMinimumRoll(Descriptor theDescriptor, Game theGame);
    }
}
