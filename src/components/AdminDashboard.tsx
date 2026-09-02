import { useEffect, useState } from 'react';
import { Users, BookOpen, MessageSquare, Flag, Shield, Activity, ChevronRight, Search } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import type { Profile, Role } from '@/types';

export function AdminDashboard({ onNavigate }: { onNavigate: (view: string) => void }) {
  const [stats, setStats] = useState({ users: 0, students: 0, teachers: 0, classes: 0, channels: 0, messagesToday: 0, pendingReports: 0 });
  const [allUsers, setAllUsers] = useState<Profile[]>([]);
  const [userSearch, setUserSearch] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => { loadStats(); loadUsers(); }, []);

  const loadStats = async () => {
    const [{ count: users }, { count: classes }, { count: channels }, { count: reports }, { count: messages }] = await Promise.all([
      supabase.from('profiles').select('*', { count: 'exact', head: true }),
      supabase.from('classes').select('*', { count: 'exact', head: true }),
      supabase.from('channels').select('*', { count: 'exact', head: true }),
      supabase.from('reports').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
      supabase.from('messages').select('*', { count: 'exact', head: true }).gte('created_at', new Date(Date.now() - 86400000).toISOString()),
    ]);
    setStats(s => ({ ...s, users: users || 0, classes: classes || 0, channels: channels || 0, pendingReports: reports || 0, messagesToday: messages || 0 }));
  };

  const loadUsers = async () => {
    const { data } = await supabase.from('profiles').select('*').order('created_at', { ascending: false }).limit(50);
    setAllUsers((data || []) as Profile[]);
    const students = (data || []).filter((u: Profile) => u.role === 'student').length;
    const teachers = (data || []).filter((u: Profile) => u.role === 'teacher').length;
    setStats(s => ({ ...s, students, teachers }));
    setLoading(false);
  };

  const changeRole = async (userId: string, role: Role) => {
    const { error } = await supabase.rpc('set_user_role', { target_uuid: userId, new_role: role });
    if (error) alert(error.message);
    else { setAllUsers(prev => prev.map(u => u.id === userId ? { ...u, role } : u)); }
  };

  const filtered = allUsers.filter(u => u.display_name.toLowerCase().includes(userSearch.toLowerCase()) || u.username.toLowerCase().includes(userSearch.toLowerCase()));

  const cards = [
    { label: 'Total Users', value: stats.users, icon: <Users size={18} />, accent: 'blue' },
    { label: 'Students', value: stats.students, icon: <Users size={18} />, accent: 'green' },
    { label: 'Teachers', value: stats.teachers, icon: <Users size={18} />, accent: 'amber' },
    { label: 'Classes', value: stats.classes, icon: <BookOpen size={18} />, accent: 'blue' },
    { label: 'Channels', value: stats.channels, icon: <MessageSquare size={18} />, accent: 'green' },
    { label: 'Messages Today', value: stats.messagesToday, icon: <Activity size={18} />, accent: 'amber' },
    { label: 'Pending Reports', value: stats.pendingReports, icon: <Flag size={18} />, accent: 'red' },
  ];

  return (
    <div className="flex-1 overflow-y-auto px-5 py-8 sm:px-8 lg:px-12 pb-24 lg:pb-8">
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center gap-3 mb-8">
          <div className="h-11 w-11 rounded-2xl bg-[#173e62] flex items-center justify-center text-[#71c2ff]"><Shield size={22} /></div>
          <div>
            <h2 className="font-display text-3xl font-bold text-white">Admin Dashboard</h2>
            <p className="text-sm text-[#718ba6] mt-1">Manage your school's SchoolChat platform</p>
          </div>
        </div>

        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-7 gap-3 mb-8">
          {cards.map(card => (
            <div key={card.label} className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-4">
              <div className={`h-9 w-9 rounded-xl flex items-center justify-center mb-3 ${card.accent === 'blue' ? 'bg-[#173e62] text-[#71c2ff]' : card.accent === 'green' ? 'bg-[#174c43] text-[#61d3ad]' : card.accent === 'amber' ? 'bg-[#55401e] text-[#f1bd62]' : 'bg-[#4a2233] text-[#ff9eb0]'}`}>{card.icon}</div>
              <div className="text-2xl font-display font-bold text-white">{card.value}</div>
              <div className="text-xs text-[#738ca6] mt-0.5">{card.label}</div>
            </div>
          ))}
        </div>

        <div className="grid lg:grid-cols-[1fr_300px] gap-5">
          <section className="rounded-2xl border border-[#243a53] bg-[#101d2e] p-5">
            <div className="flex items-center justify-between mb-5">
              <h3 className="font-display font-bold text-white">User Management</h3>
              <div className="flex items-center gap-2 rounded-lg border border-[#304b67] bg-[#14253a] px-2">
                <Search size={14} className="text-[#7192ad]" />
                <input value={userSearch} onChange={e => setUserSearch(e.target.value)} placeholder="Search users" className="w-32 bg-transparent py-2 text-xs text-white outline-none" />
              </div>
            </div>
            {loading ? <div className="flex justify-center py-8"><div className="h-6 w-6 rounded-full border-2 border-[#3e8abc] border-t-transparent animate-spin" /></div> :
             <div className="space-y-2">
               {filtered.map(user => (
                 <div key={user.id} className="flex items-center gap-3 rounded-xl border border-[#29435e] bg-[#13263b] p-3">
                   <div className="h-9 w-9 rounded-xl flex items-center justify-center text-xs font-bold text-white shrink-0" style={{ background: user.avatar_color }}>{user.display_name.slice(0, 2).toUpperCase()}</div>
                   <div className="min-w-0 flex-1">
                     <div className="font-semibold text-white text-sm truncate">{user.display_name}</div>
                     <div className="text-xs text-[#7793ad]">@{user.username}</div>
                   </div>
                   <select value={user.role} onChange={e => changeRole(user.id, e.target.value as Role)} className="rounded-lg border border-[#3b5874] bg-[#0c1828] px-2 py-1.5 text-xs text-white outline-none">
                     <option value="student">Student</option>
                     <option value="teacher">Teacher</option>
                     <option value="moderator">Moderator</option>
                     <option value="admin">Admin</option>
                   </select>
                 </div>
               ))}
               {!filtered.length && <div className="text-sm text-[#7189a3] text-center py-6">No users found</div>}
             </div>}
          </section>

          <section className="space-y-2">
            {[
              { label: 'Classes & Sections', icon: <BookOpen size={17} />, view: 'admin-classes' },
              { label: 'Channels', icon: <MessageSquare size={17} />, view: 'admin-channels' },
              { label: 'Reports', icon: <Flag size={17} />, view: 'admin-reports' },
              { label: 'Moderation', icon: <Shield size={17} />, view: 'admin-moderation' },
              { label: 'Audit Logs', icon: <Activity size={17} />, view: 'admin-audit' },
            ].map(item => (
              <button key={item.view} onClick={() => onNavigate(item.view)} className="w-full flex items-center gap-3 rounded-2xl border border-[#243a53] bg-[#101d2e] p-4 text-left hover:border-[#4d98ca] hover:bg-[#17304a] transition">
                <div className="h-9 w-9 rounded-xl bg-[#1d3045] flex items-center justify-center text-[#72c4ff]">{item.icon}</div>
                <span className="flex-1 text-sm font-semibold text-[#dbe9f5]">{item.label}</span>
                <ChevronRight size={16} className="text-[#557693]" />
              </button>
            ))}
          </section>
        </div>
      </div>
    </div>
  );
}
