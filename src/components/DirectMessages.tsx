import { useEffect, useMemo, useRef, useState } from 'react';
import { Send, ArrowLeft, MessageCircle, Search, Image as ImageIcon, X } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import type { ClassMember, DMConversation, DirectMessage, Profile } from '@/types';

const formatTime = (date: string) => new Intl.DateTimeFormat('en', { hour: 'numeric', minute: '2-digit' }).format(new Date(date));

interface GifResult { id: string; url: string; preview: string; }

export function DirectMessages({ userId, friends, classMembers, dmTargetId, onDmStarted }: { userId: string; friends: Profile[]; classMembers: ClassMember[]; dmTargetId: string | null; onDmStarted: () => void }) {
  const [conversations, setConversations] = useState<DMConversation[]>([]);
  const [selected, setSelected] = useState<DMConversation | null>(null);
  const [messages, setMessages] = useState<DirectMessage[]>([]);
  const [composer, setComposer] = useState('');
  const [loading, setLoading] = useState(true);
  const [showNew, setShowNew] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [showGifPicker, setShowGifPicker] = useState(false);
  const [gifSearch, setGifSearch] = useState('');
  const [gifResults, setGifResults] = useState<GifResult[]>([]);
  const [gifLoading, setGifLoading] = useState(false);
  const [error, setError] = useState('');
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

  useEffect(() => { if (dmTargetId) startConversationWithUser(dmTargetId); }, [dmTargetId]);

  useEffect(() => {
    if (!showGifPicker) return;
    if (!gifSearch) loadTrendingGifs();
    else searchGifs(gifSearch);
  }, [showGifPicker]);

  useEffect(() => {
    if (!showGifPicker || !gifSearch) return;
    const timer = setTimeout(() => searchGifs(gifSearch), 400);
    return () => clearTimeout(timer);
  }, [gifSearch]);

  useEffect(() => { if (!error) return; const timer = window.setTimeout(() => setError(''), 3500); return () => window.clearTimeout(timer); }, [error]);

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
      .select('conversation_id, content, message_type, created_at')
      .in('conversation_id', convIds)
      .order('created_at', { ascending: false });
    const lastByConv = new Map((lastMsgs || []).map(m => [m.conversation_id, m]));
    const convMap = new Map<string, DMConversation>();
    for (const p of (allParts || [])) {
      const last = lastByConv.get(p.conversation_id);
      convMap.set(p.conversation_id, {
        id: p.conversation_id,
        other_user: p.profiles as unknown as Profile,
        last_message: last?.message_type === 'gif' ? 'GIF' : last?.content,
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
    await startConversationWithUser(friend.id);
  };

  const startConversationWithUser = async (targetUserId: string) => {
    const { data: convId, error } = await supabase.rpc('create_dm_with_member', { target_user_id: targetUserId });
    if (error) { setError(error.message.includes('only message') ? 'You can only message friends or members of your classes.' : 'Unable to start conversation. Please try again.'); return; }
    if (!convId) return;
    const { data: parts } = await supabase
      .from('direct_message_participants')
      .select('user_id, profiles(*)')
      .eq('conversation_id', convId)
      .neq('user_id', userId)
      .maybeSingle();
    const otherUser = parts?.profiles as unknown as Profile;
    setSelected({ id: convId as string, other_user: otherUser });
    setShowNew(false);
    await loadConversations();
    if (onDmStarted) onDmStarted();
  };

  const sendDM = async () => {
    const content = composer.trim();
    if (!content || !selected) return;
    setComposer('');
    const { data, error } = await supabase
      .from('direct_messages')
      .insert({ conversation_id: selected.id, sender_id: userId, content, message_type: 'text' })
      .select('*, profiles(*)')
      .maybeSingle();
    if (error) { setError('Failed to send message. Please try again.'); setComposer(content); }
    else if (data) setMessages(prev => [...prev, data as DirectMessage]);
  };

  const sendGif = async (gif: GifResult) => {
    if (!selected) return;
    setShowGifPicker(false);
    const { data, error } = await supabase
      .from('direct_messages')
      .insert({ conversation_id: selected.id, sender_id: userId, content: gif.url, message_type: 'gif', gif_url: gif.url })
      .select('*, profiles(*)')
      .maybeSingle();
    if (error) setError('Failed to send GIF. Please try again.');
    else if (data) setMessages(prev => [...prev, data as DirectMessage]);
  };

  const loadTrendingGifs = async () => {
    setGifLoading(true);
    try {
      const res = await fetch(`https://api.giphy.com/v1/gifs/trending?api_key=dc6zaTOxFJmzC&limit=24`);
      const json = await res.json();
      setGifResults((json.data || []).map((g: any) => ({ id: g.id, url: g.images.original.url, preview: g.images.fixed_height_small.url })));
    } catch { /* GIPHY public API */ }
    setGifLoading(false);
  };

  const searchGifs = async (query: string) => {
    if (!query.trim()) { loadTrendingGifs(); return; }
    setGifLoading(true);
    try {
      const res = await fetch(`https://api.giphy.com/v1/gifs/search?api_key=dc6zaTOxFJmzC&q=${encodeURIComponent(query)}&limit=24`);
      const json = await res.json();
      setGifResults((json.data || []).map((g: any) => ({ id: g.id, url: g.images.original.url, preview: g.images.fixed_height_small.url })));
    } catch { /* GIPHY public API */ }
    setGifLoading(false);
  };

  const allContacts = useMemo(() => {
    const map = new Map<string, Profile>();
    for (const f of friends) map.set(f.id, f);
    for (const m of classMembers) {
      if (m.profiles && m.user_id !== userId) map.set(m.user_id, m.profiles);
    }
    return [...map.values()];
  }, [friends, classMembers, userId]);

  const filteredContacts = allContacts.filter(f =>
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
                {filteredContacts.map(f => (
                  <button key={f.id} onClick={() => startConversation(f)} className="w-full flex items-center gap-2 rounded-lg px-2 py-2 text-left hover:bg-[#1d3852] transition">
                    <div className="h-7 w-7 rounded-lg flex items-center justify-center text-[10px] font-bold text-white" style={{ background: f.avatar_color }}>{f.display_name.slice(0, 2).toUpperCase()}</div>
                    <span className="text-xs text-[#c2d1df] truncate">{f.display_name}</span>
                  </button>
                ))}
                {!filteredContacts.length && <div className="text-xs text-[#7189a3] text-center py-3">No contacts found</div>}
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
          )) : <div className="px-4 py-8 text-center text-sm text-[#7189a3]">No conversations yet. Start one from your friends list or a server member profile.</div>}
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
                        {msg.is_deleted ? <div className="rounded-2xl px-4 py-2.5 text-sm italic text-[#667e97] bg-[#192d45]">Message removed</div>
                        : msg.message_type === 'gif' && msg.gif_url ? <img src={msg.gif_url} alt="GIF" className="rounded-2xl max-w-full max-h-72 object-contain" />
                        : <div className={`rounded-2xl px-4 py-2.5 text-sm leading-6 ${own ? 'bg-[#247bbb] text-white' : 'bg-[#192d45] text-[#c2d2e1]'}`}>{msg.content}</div>}
                      </div>
                    </div>
                  );
                })}
                {!messages.length && <div className="text-center text-sm text-[#7189a3] py-12">Start your conversation with {selected.other_user.display_name}.</div>}
              </div>
            </div>

            {/* GIF Picker */}
            {showGifPicker && (
              <div className="absolute bottom-[72px] left-4 right-4 sm:left-8 sm:right-8 max-w-3xl mx-auto rounded-2xl border border-[#2a4661] bg-[#101b2b] shadow-2xl z-30 max-h-80 flex flex-col">
                <div className="flex items-center gap-2 border-b border-[#20324a] p-3">
                  <Search size={15} className="text-[#7192ad]" />
                  <input value={gifSearch} onChange={e => setGifSearch(e.target.value)} placeholder="Search GIFs..." className="flex-1 bg-transparent text-sm text-white outline-none placeholder:text-[#6e88a2]" autoFocus />
                  <button onClick={() => setShowGifPicker(false)} className="text-[#7189a3] hover:text-white"><X size={16} /></button>
                </div>
                <div className="flex-1 overflow-y-auto p-3">
                  {gifLoading ? <div className="flex justify-center py-8"><div className="h-6 w-6 rounded-full border-2 border-[#3e8abc] border-t-transparent animate-spin" /></div> :
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    {gifResults.map(gif => (
                      <button key={gif.id} onClick={() => sendGif(gif)} className="rounded-lg overflow-hidden hover:opacity-80 transition">
                        <img src={gif.preview} alt="" className="w-full h-28 object-cover" />
                      </button>
                    ))}
                  </div>}
                </div>
              </div>
            )}

            <div className="px-4 sm:px-8 pb-6 relative">
              <div className="max-w-3xl mx-auto flex items-end gap-2 rounded-2xl border border-[#2a4661] bg-[#132439] p-2">
                <button onClick={() => setShowGifPicker(!showGifPicker)} className={`rounded-xl p-2.5 transition ${showGifPicker ? 'bg-[#1d3852] text-[#75c5ff]' : 'text-[#7c99b2] hover:bg-[#1d3852] hover:text-white'}`} title="Send a GIF"><ImageIcon size={18} /></button>
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
              <div className="mt-1 text-xs text-[#7089a5]">Select a conversation or start a new one with a friend or server member.</div>
            </div>
          </div>
        )}
      </div>
      {error && <div className="fixed bottom-6 left-1/2 -translate-x-1/2 z-50 rounded-xl border border-[#7e3b4c] bg-[#3a1d2a] px-4 py-3 text-sm text-[#ffb8c6] shadow-2xl">{error}</div>}
    </div>
  );
}
