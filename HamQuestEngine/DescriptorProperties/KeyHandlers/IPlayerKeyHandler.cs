using System;
using System.Net;
using System.Windows;



using System.Windows.Input;




namespace HamQuestEngine
{
    public interface IPlayerKeyHandler
    {
        bool HandleKey(Key key, Descriptor descriptor); 
    }
}
