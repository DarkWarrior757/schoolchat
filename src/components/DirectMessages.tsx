import { useEffect, useRef, useState } from 'react';
import { Send, ArrowLeft, MessageCircle, Search } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import type { DMConversation, DirectMessage, Profile } from '@/types';

const formatTime = (date: string) => new Intl.DateTimeFormat('en', { hour: 'numeric', minute: '2-digit' }).format(new Date(date));

export function DirectMessages({ userId, friends }: { userId: string; friends: Profile[] }) {
  const [conversations, setConversations] = useState<DMConversation[]>([]);
  const [selected, setSelected] = useState<DMConversation | null>(null);
  const [messages, setMessages] = useState<DirectMessage[]>([]);
  const [composer, setComposer] = useState('');
  const [loading, setLoading] = useState(true);
  const [showNew, setShowNew] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => { loadConversations(); }, [userId]);

  useEffect(() => {
    if (!selected) return;
    loadMessages(selected.id);
    const channel = supabase
      .channel(`dm:${selected.id}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'direct_messages', filter: `conversation_id=eq.${selected.id}` }, async payload => {
        const { data } = await supabase.from('direct_messages').select('*, profiles(*)').eq('id', payload.new.id).maybeSingle();
        if (data) setMessages(prev => prev.some(m => m.id === data.id) ? prev : [...prev, data as DirectMessage]);
      })
      .subscribe();
    return () => { void supabase.removeChannel(channel); };
  }, [selected?.id]);

  useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight; }, [messages]);

  const loadConversations = async () => {
    const { data: parts } = await supabase
      .from('direct_message_participants')
      .select('conversation_id')
      .eq('user_id', userId);
    if (!parts?.length) { setLoading(false); return; }
    const convIds = parts.map(p => p.conversation_id);
    const { data: allParts } = await supabase
      .from('direct_message_participants')
      .select('conversation_id, user_id, profiles(*)')
      .in('conversation_id', convIds)
      .neq('user_id', userId);
    const { data: lastMsgs } = await supabase
      .from('direct_messages')
      .select('conversation_id, content, created_at')
      .in('conversation_id', convIds)
      .order('created_at', { ascending: false });
    const lastByConv = new Map((lastMsgs || []).map(m => [m.conversation_id, m]));
    const convMap = new Map<string, DMConversation>();
    for (const p of (allParts || [])) {
      const last = lastByConv.get(p.conversation_id);
      convMap.set(p.conversation_id, {
        id: p.conversation_id,
        other_user: p.profiles as unknown as Profile,
        last_message: last?.content,
        last_at: last?.created_at,
      });
    }
    setConversations([...convMap.values()].sort((a, b) => (b.last_at || '').localeCompare(a.last_at || '')));
    setLoading(false);
  };

  const loadMessages = async (convId: string) => {
    const { data } = await supabase
      .from('direct_messages')
      .select('*, profiles(*)')
      .eq('conversation_id', convId)
      .order('created_at', { ascending: true })
      .limit(100);
    setMessages((data || []) as DirectMessage[]);
  };

  const startConversation = async (friend: Profile) => {
    const { data: existing } = await supabase
      .from('direct_message_participants')
      .select('conversation_id')
      .eq('user_id', userId)
      .maybeSingle();
    // Check if conversation already exists with this friend
    if (existing) {
      const { data: allParts } = await supabase
        .from('direct_message_participants')
        .select('conversation_id, user_id')
        .in('conversation_id', [existing.conversation_id]);
      for (const row of (allParts || [])) {
        if (row.user_id === friend.id) {
          setSelected({ id: row.conversation_id, other_user: friend });
          setShowNew(false);
          return;
        }
      }
    }
    // Create new conversation
    const { data: conv } = await supabase.from('direct_message_conversations').insert({}).select().maybeSingle();
    if (!conv) return;
    await supabase.from('direct_message_participants').insert([
      { conversation_id: conv.id, user_id: userId },
      { conversation_id: conv.id, user_id: friend.id },
    ]);
    setSelected({ id: conv.id, other_user: friend });
    setShowNew(false);
    await loadConversations();
  };

  const sendDM = async () => {
    const content = composer.trim();
    if (!content || !selected) return;
    setComposer('');
    const { data, error } = await supabase
      .from('direct_messages')
      .insert({ conversation_id: selected.id, sender_id: userId, content })
      .select('*, profiles(*)')
      .maybeSingle();
    if (!error && data) setMessages(prev => [...prev, data as DirectMessage]);
  };

  const filteredFriends = friends.filter(f =>
    f.display_name.toLowerCase().includes(searchTerm.toLowerCase()) ||
    f.username.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div className="flex-1 min-h-0 flex">
      {/* Conversation list */}
      <div className={`w-full sm:w-72 shrink-0 border-r border-[#20324a] bg-[#101b2b] flex flex-col ${selected ? 'hidden sm:flex' : 'flex'}`}>
        <div className="h-[74px] shrink-0 border-b border-[#20324a] flex items-center px-5">
          <h2 className="font-display font-bold text-white">Messages</h2>
        </div>
        <div className="p-3">
          <button onClick={() => setShowNew(!showNew)} className="w-full rounded-xl border border-[#2a4661] bg-[#132439] px-3 py-2.5 text-sm text-[#91aac2] hover:border-[#4389b6] transition">
            + New message
          </button>
          {showNew && (
            <div className="mt-3 rounded-xl border border-[#2a4661] bg-[#0c1828] p-3">
              <div className="flex items-center gap-2 rounded-lg border border-[#304b67] bg-[#14253a] px-2 mb-2">
                <Search size={14} className="text-[#7192ad]" />
                <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)} placeholder="Search friends" className="w-full bg-transparent py-2 text-xs text-white outline-none" />
              </div>
              <div className="max-h-48 overflow-y-auto space-y-1">
                {filteredFriends.map(f => (
                  <button key={f.id} onClick={() => startConversation(f)} className="w-full flex items-center gap-2 rounded-lg px-2 py-2 text-left hover:bg-[#1d3852] transition">
                    <div className="h-7 w-7 rounded-lg flex items-center justify-center text-[10px] font-bold text-white" style={{ background: f.avatar_color }}>{f.display_name.slice(0, 2).toUpperCase()}</div>
                    <span className="text-xs text-[#c2d1df] truncate">{f.display_name}</span>
                  </button>
                ))}
                {!filteredFriends.length && <div className="text-xs text-[#7189a3] text-center py-3">No friends found</div>}
              </div>
            </div>
          )}
        </div>
        <div className="flex-1 overflow-y-auto px-2">
          {loading ? <div className="flex justify-center py-8"><div className="h-6 w-6 rounded-full border-2 border-[#3e8abc] border-t-transparent animate-spin" /></div> :
           conversations.length ? conversations.map(conv => (
            <button key={conv.id} onClick={() => setSelected(conv)} className={`w-full flex items-center gap-3 rounded-xl px-3 py-3 text-left transition ${selected?.id === conv.id ? 'bg-[#213c5a]' : 'hover:bg-[#192d45]'}`}>
              <div className="h-9 w-9 rounded-xl flex items-center justify-center text-xs font-bold text-white shrink-0" style={{ background: conv.other_user.avatar_color }}>{conv.other_user.display_name.slice(0, 2).toUpperCase()}</div>
              <div className="min-w-0 flex-1">
                <div className="text-sm font-semibold text-[#dbe9f5] truncate">{conv.other_user.display_name}</div>
                <div className="text-xs text-[#7189a3] truncate">{conv.last_message || 'No messages yet'}</div>
              </div>
            </button>
          )) : <div className="px-4 py-8 text-center text-sm text-[#7189a3]">No conversations yet. Start one from your friends list.</div>}
        </div>
      </div>

      {/* Chat area */}
      <div className={`flex-1 min-w-0 flex flex-col ${selected ? 'flex' : 'hidden sm:flex'}`}>
        {selected ? (
          <>
            <div className="h-[74px] shrink-0 border-b border-[#20324a] flex items-center gap-3 px-5">
              <button onClick={() => setSelected(null)} className="sm:hidden text-[#91aac2]"><ArrowLeft size={20} /></button>
              <div className="h-9 w-9 rounded-xl flex items-center justify-center text-xs font-bold text-white" style={{ background: selected.other_user.avatar_color }}>{selected.other_user.display_name.slice(0, 2).toUpperCase()}</div>
              <div>
                <div className="font-display font-bold text-white">{selected.other_user.display_name}</div>
                <div className="text-xs text-[#7189a3]">@{selected.other_user.username}</div>
              </div>
            </div>
            <div ref={scrollRef} className="flex-1 min-h-0 overflow-y-auto px-4 sm:px-8 py-6">
              <div className="max-w-3xl mx-auto space-y-4">
                {messages.map(msg => {
                  const own = msg.sender_id === userId;
                  return (
                    <div key={msg.id} className={`flex gap-3 ${own ? 'flex-row-reverse' : ''}`}>
                      <div className="h-8 w-8 rounded-lg flex items-center justify-center text-[10px] font-bold text-white shrink-0" style={{ background: msg.profiles?.avatar_color || '#2777b8' }}>{(msg.profiles?.display_name || '?').slice(0, 2).toUpperCase()}</div>
                      <div className={`max-w-[75%] ${own ? 'items-end' : ''} flex flex-col`}>
                        <div className="text-[11px] text-[#6d88a3] mb-1">{msg.profiles?.display_name} · {formatTime(msg.created_at)}</div>
                        <div className={`rounded-2xl px-4 py-2.5 text-sm leading-6 ${own ? 'bg-[#247bbb] text-white' : 'bg-[#192d45] text-[#c2d2e1]'}`}>{msg.is_deleted ? <span className="italic text-[#667e97]">Message removed</span> : msg.content}</div>
                      </div>
                    </div>
                  );
                })}
                {!messages.length && <div className="text-center text-sm text-[#7189a3] py-12">Start your conversation with {selected.other_user.display_name}.</div>}
              </div>
            </div>
            <div className="px-4 sm:px-8 pb-6">
              <div className="max-w-3xl mx-auto flex items-end gap-2 rounded-2xl border border-[#2a4661] bg-[#132439] p-2">
                <textarea value={composer} onChange={e => setComposer(e.target.value)} onKeyDown={e => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendDM(); } }} rows={1} placeholder={`Message ${selected.other_user.display_name}...`} className="max-h-28 min-h-[42px] flex-1 resize-none bg-transparent px-3 py-2.5 text-sm text-white outline-none placeholder:text-[#6e88a2]" />
                <button onClick={sendDM} disabled={!composer.trim()} className="rounded-xl bg-[#277eb8] p-2.5 text-white hover:bg-[#3591cf] disabled:opacity-40"><Send size={17} /></button>
              </div>
            </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center">
            <div className="text-center">
              <div className="mx-auto h-14 w-14 rounded-2xl bg-[#1a2d43] flex items-center justify-center text-[#72b8e7] mb-4"><MessageCircle size={28} /></div>
              <div className="text-sm font-semibold text-[#c6d6e4]">Your messages</div>
              <div className="mt-1 text-xs text-[#7089a5]">Select a conversation or start a new one with a friend.</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
