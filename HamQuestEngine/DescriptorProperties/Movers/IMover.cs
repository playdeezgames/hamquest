
namespace HamQuestEngine
{
    public interface IMover
    {
        void DoMove(Creature theCreature, ref int nextColumn, ref int nextRow, Game theGame);
    }
}
