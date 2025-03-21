<script setup>
import { ref, reactive, onMounted } from 'vue'
import { Howl } from 'howler'

const audioFiles = ref([])
const currentTrack = ref(null)
const sound = ref(null)
const isPlaying = ref(false)
const currentTime = ref(0)
const duration = ref(0)
const volume = ref(0.8)
const loading = ref(true)
const error = ref(null)

// 从服务器获取音乐元数据
const fetchMusicData = async () => {
  try {
    loading.value = true
    error.value = null
    
    const response = await fetch('/music/playlist.json')
    if (!response.ok) {
      throw new Error('无法加载音乐列表，请检查服务器配置')
    }
    
    const data = await response.json()
    audioFiles.value = data.map(item => ({
      id: item.id,
      name: item.title,
      artist: item.artist,
      album: item.album,
      cover: `/music/${item.cover}`,
      url: `/music/${item.file}`
    }))
    
    if (audioFiles.value.length > 0) {
      currentTrack.value = audioFiles.value[0]
      loadSound(currentTrack.value)
    }
  } catch (err) {
    console.error('加载音乐数据失败:', err)
    error.value = err.message
  } finally {
    loading.value = false
  }
}

// 加载并初始化音频
const loadSound = (track) => {
  if (sound.value) {
    sound.value.unload()
  }
  
  sound.value = new Howl({
    src: [track.url],
    html5: true,
    volume: volume.value,
    onplay: () => {
      isPlaying.value = true
      requestAnimationFrame(updateProgress)
    },
    onpause: () => {
      isPlaying.value = false
    },
    onend: () => {
      isPlaying.value = false
      playNext()
    },
    onload: () => {
      duration.value = sound.value.duration()
    },
    onloaderror: (id, err) => {
      console.error('音频加载失败:', err)
      error.value = `无法加载音频: ${track.name}`
    }
  })
}

// 播放/暂停控制
const togglePlay = () => {
  if (!sound.value) return
  
  if (isPlaying.value) {
    sound.value.pause()
  } else {
    sound.value.play()
  }
}

// 播放下一首
const playNext = () => {
  if (!currentTrack.value || audioFiles.value.length <= 1) return
  
  const currentIndex = audioFiles.value.findIndex(track => track.id === currentTrack.value.id)
  const nextIndex = (currentIndex + 1) % audioFiles.value.length
  currentTrack.value = audioFiles.value[nextIndex]
  loadSound(currentTrack.value)
  sound.value.play()
}

// 播放上一首
const playPrev = () => {
  if (!currentTrack.value || audioFiles.value.length <= 1) return
  
  const currentIndex = audioFiles.value.findIndex(track => track.id === currentTrack.value.id)
  const prevIndex = (currentIndex - 1 + audioFiles.value.length) % audioFiles.value.length
  currentTrack.value = audioFiles.value[prevIndex]
  loadSound(currentTrack.value)
  sound.value.play()
}

// 更新进度条
const updateProgress = () => {
  if (sound.value && isPlaying.value) {
    currentTime.value = sound.value.seek()
    requestAnimationFrame(updateProgress)
  }
}

// 设置进度
const setProgress = (e) => {
  if (!sound.value) return
  
  const progressBar = e.target
  const percent = e.offsetX / progressBar.offsetWidth
  const seekTime = percent * duration.value
  sound.value.seek(seekTime)
  currentTime.value = seekTime
}

// 设置音量
const setVolume = (e) => {
  volume.value = e.target.value
  if (sound.value) {
    sound.value.volume(volume.value)
  }
}

// 格式化时间
const formatTime = (seconds) => {
  if (!seconds || isNaN(seconds)) return '0:00'
  const mins = Math.floor(seconds / 60)
  const secs = Math.floor(seconds % 60)
  return `${mins}:${secs < 10 ? '0' : ''}${secs}`
}

// 选择并播放特定曲目
const selectTrack = (track) => {
  currentTrack.value = track
  loadSound(track)
  sound.value.play()
}

// 页面加载时获取音乐数据
onMounted(() => {
  fetchMusicData()
})
</script>

<template>
  <div class="music-player">
    <h1>诺多音乐播放器</h1>
    
    <div v-if="loading" class="loading">
      <p>加载音乐列表中...</p>
    </div>
    
    <div v-else-if="error" class="error">
      <p>{{ error }}</p>
      <button @click="fetchMusicData" class="retry-btn">重试</button>
    </div>
    
    <div v-else-if="audioFiles.length > 0" class="player-container">
      <div class="now-playing">
        <div class="cover-container">
          <img 
            v-if="currentTrack?.cover" 
            :src="currentTrack.cover" 
            :alt="currentTrack.name" 
            class="cover-image"
          />
          <div v-else class="cover-placeholder"></div>
        </div>
        
        <div class="track-info">
          <h3 class="track-name">{{ currentTrack?.name || '未选择音乐' }}</h3>
          <p class="track-artist">{{ currentTrack?.artist || '未知艺术家' }}</p>
          <p class="track-album">{{ currentTrack?.album || '未知专辑' }}</p>
        </div>
      </div>
      
      <div class="progress-container" @click="setProgress">
        <div class="progress-bar">
          <div 
            class="progress" 
            :style="{ width: `${(currentTime / duration) * 100}%` }"
          ></div>
        </div>
        <div class="time">
          <span>{{ formatTime(currentTime) }}</span>
          <span>{{ formatTime(duration) }}</span>
        </div>
      </div>
      
      <div class="controls">
        <button @click="playPrev" class="control-btn">上一首</button>
        <button @click="togglePlay" class="control-btn play-btn">
          {{ isPlaying ? '暂停' : '播放' }}
        </button>
        <button @click="playNext" class="control-btn">下一首</button>
      </div>
      
      <div class="volume-control">
        <label for="volume">音量:</label>
        <input 
          id="volume" 
          type="range" 
          min="0" 
          max="1" 
          step="0.01" 
          v-model="volume" 
          @input="setVolume"
        />
      </div>
      
      <div class="playlist">
        <h3>播放列表</h3>
        <ul>
          <li 
            v-for="track in audioFiles" 
            :key="track.id" 
            @click="selectTrack(track)"
            :class="{ active: currentTrack?.id === track.id }"
          >
            <div class="track-list-item">
              <img 
                v-if="track.cover" 
                :src="track.cover" 
                :alt="track.name" 
                class="track-list-cover"
              />
              <div class="track-list-info">
                <div class="track-list-name">{{ track.name }}</div>
                <div class="track-list-artist">{{ track.artist }}</div>
              </div>
            </div>
          </li>
        </ul>
      </div>
    </div>
    
    <div v-else class="empty-state">
      <p>没有找到音乐文件</p>
      <p class="hint">请在服务器的 /music 目录下添加音乐文件，并更新 playlist.json</p>
    </div>
  </div>
</template>

<style scoped>
.music-player {
  max-width: 800px;
  margin: 0 auto;
  padding: 2rem;
  font-family: 'Arial', sans-serif;
}

h1 {
  text-align: center;
  color: #333;
  margin-bottom: 2rem;
}

.loading, .error, .empty-state {
  text-align: center;
  padding: 2rem;
  background: #f5f5f5;
  border-radius: 8px;
  margin-top: 2rem;
}

.error {
  color: #e53935;
}

.retry-btn, .hint {
  margin-top: 1rem;
  display: inline-block;
}

.retry-btn {
  background: #4a6bff;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
}

.hint {
  color: #777;
  font-size: 0.9rem;
}

.player-container {
  background: #f5f5f5;
  border-radius: 8px;
  padding: 1.5rem;
  box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
}

.now-playing {
  display: flex;
  align-items: center;
  margin-bottom: 1.5rem;
}

.cover-container {
  width: 120px;
  height: 120px;
  margin-right: 1.5rem;
  flex-shrink: 0;
}

.cover-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: 4px;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.1);
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  background: #ddd;
  border-radius: 4px;
}

.track-info {
  flex: 1;
}

.track-name {
  font-size: 1.4rem;
  font-weight: bold;
  margin: 0 0 0.5rem;
  color: #333;
}

.track-artist {
  font-size: 1rem;
  color: #555;
  margin: 0 0 0.3rem;
}

.track-album {
  font-size: 0.9rem;
  color: #777;
  margin: 0;
}

.progress-container {
  margin-bottom: 1.5rem;
}

.progress-bar {
  height: 8px;
  background: #ddd;
  border-radius: 4px;
  cursor: pointer;
  margin-bottom: 0.5rem;
}

.progress {
  height: 100%;
  background: #4a6bff;
  border-radius: 4px;
  transition: width 0.1s linear;
}

.time {
  display: flex;
  justify-content: space-between;
  font-size: 0.9rem;
  color: #777;
}

.controls {
  display: flex;
  justify-content: center;
  gap: 1rem;
  margin-bottom: 1.5rem;
}

.control-btn {
  border: none;
  background: #e0e0e0;
  padding: 0.6rem 1.2rem;
  border-radius: 4px;
  cursor: pointer;
  font-weight: bold;
  transition: background 0.2s;
}

.control-btn:hover {
  background: #d0d0d0;
}

.play-btn {
  background: #4a6bff;
  color: white;
  padding: 0.6rem 2rem;
}

.play-btn:hover {
  background: #3a58e0;
}

.volume-control {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 1.5rem;
}

.volume-control input {
  flex: 1;
}

.playlist {
  border-top: 1px solid #ddd;
  padding-top: 1rem;
}

.playlist h3 {
  margin-bottom: 0.8rem;
  color: #555;
}

.playlist ul {
  list-style: none;
  padding: 0;
  margin: 0;
  max-height: 300px;
  overflow-y: auto;
}

.playlist li {
  border-bottom: 1px solid #eee;
  cursor: pointer;
  transition: background 0.2s;
}

.playlist li:hover {
  background: #eaeaea;
}

.playlist li.active {
  background: #e6ecff;
}

.playlist li.active .track-list-name {
  color: #4a6bff;
  font-weight: bold;
}

.track-list-item {
  display: flex;
  align-items: center;
  padding: 0.8rem 1rem;
}

.track-list-cover {
  width: 40px;
  height: 40px;
  object-fit: cover;
  border-radius: 4px;
  margin-right: 0.8rem;
}

.track-list-info {
  flex: 1;
  min-width: 0;
}

.track-list-name {
  font-weight: 500;
  margin-bottom: 0.2rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.track-list-artist {
  font-size: 0.85rem;
  color: #777;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
</style>
