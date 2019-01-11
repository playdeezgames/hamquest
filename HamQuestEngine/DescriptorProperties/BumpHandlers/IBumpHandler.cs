using System;
using System.Net;
using System.Windows;



using System.Windows.Input;



using System.Xml.Linq;

namespace HamQuestEngine
{
    public enum BumpResult
    {
        Deny,
        Allow
    }
    public interface IBumpHandler
    {
        BumpResult Bump(Descriptor theDescriptor, Creature theCreature);
    }
    public class AlwaysDenyBumpHandler:IBumpHandler
    {
        public static IBumpHandler LoadFromNode(XElement node)
        {
            return new AlwaysDenyBumpHandler();
        }

        public BumpResult Bump(Descriptor theDescriptor, Creature theCreature)
        {
            return BumpResult.Deny;
        }
    }
    public class AlwaysAllowBumpHandler:IBumpHandler
    {
        public static IBumpHandler LoadFromNode(XElement node)
        {
            return new AlwaysAllowBumpHandler();
        }

        public BumpResult Bump(Descriptor theDescriptor, Creature theCreature)
        {
            return BumpResult.Allow;
        }
    }
    public class PlayerOnlyBumpHandler : IBumpHandler
    {
        public static IBumpHandler LoadFromNode(XElement node)
        {
            return new PlayerOnlyBumpHandler();
        }

        public BumpResult Bump(Descriptor theDescriptor, Creature theCreature)
        {
            string creatureIdentifier = theCreature.CreatureIdentifier;
            Descriptor creatureDescriptor = theCreature.Game.TableSet.CreatureTable.GetCreatureDescriptor(creatureIdentifier);
            if (creatureDescriptor is PlayerDescriptor)
            {
                return BumpResult.Allow;
            }
            else
            {
                return BumpResult.Deny;
            }
        }
    }
}
