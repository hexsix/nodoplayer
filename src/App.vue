<script setup>
import { ref, reactive, onMounted, computed, watch, onUnmounted } from 'vue'
import { Howl } from 'howler'
// 移除ColorThief导入，使用自己的实现
// import ColorThief from 'color-thief-browser'

const audioFiles = ref([])
const currentTrack = ref(null)
const sound = ref(null)
const isPlaying = ref(false)
const currentTime = ref(0)
const duration = ref(0)
const volume = ref(0.8)
const loading = ref(true)
const error = ref(null)
// 不再使用ColorThief
// const colorThief = new ColorThief()
const dominantColor = ref([60, 60, 70]) // 默认颜色
const isFullScreen = ref(true) // 默认为全屏状态
const showPlaylist = ref(false)

// 预定义的颜色列表
const predefinedColors = [
  [67, 134, 205],  // 蓝色
  [156, 39, 176],  // 紫色
  [233, 30, 99],   // 粉色
  [230, 81, 0],    // 橙色
  [63, 81, 181],   // 靛蓝
  [0, 150, 136],   // 青色
  [76, 175, 80],   // 绿色
  [205, 220, 57],  // 黄绿色
  [121, 85, 72],   // 棕色
  [33, 33, 33],    // 深灰色
];

// 根据主题色计算文本颜色（深色背景用白字，浅色背景用黑字）
const textColor = computed(() => {
  const [r, g, b] = dominantColor.value
  // 计算亮度
  const brightness = (r * 299 + g * 587 + b * 114) / 1000
  return brightness > 128 ? '#000000' : '#ffffff'
})

// 背景渐变色
const backgroundStyle = computed(() => {
  const [r, g, b] = dominantColor.value
  return {
    background: `linear-gradient(to bottom, rgba(${r},${g},${b},0.8) 0%, rgba(20,20,20,0.9) 100%)`,
    color: textColor.value
  }
})

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
  
  // 加载封面并提取主题色
  if (track.cover) {
    extractColorsFromCover(track.cover)
  } else {
    // 如果没有封面，使用随机颜色
    useRandomColor()
  }
}

// 使用随机颜色
const useRandomColor = () => {
  const randomColor = predefinedColors[Math.floor(Math.random() * predefinedColors.length)]
  dominantColor.value = randomColor
}

// 从封面提取主题色 (简化版)
const extractColorsFromCover = (coverUrl) => {
  try {
    const img = new Image()
    img.crossOrigin = 'Anonymous'
    img.onload = () => {
      try {
        // 使用canvas提取颜色
        const canvas = document.createElement('canvas')
        const ctx = canvas.getContext('2d')
        
        // 设置canvas大小为图片的一小部分，提高性能
        const size = 50
        canvas.width = size
        canvas.height = size
        
        // 在canvas上绘制图片
        ctx.drawImage(img, 0, 0, img.width, img.height, 0, 0, size, size)
        
        // 获取图像数据
        const imageData = ctx.getImageData(0, 0, size, size).data
        
        // 计算平均RGB值
        let r = 0, g = 0, b = 0
        let count = 0
        
        // 每隔几个像素采样一次
        for (let i = 0; i < imageData.length; i += 20) {
          r += imageData[i]
          g += imageData[i + 1]
          b += imageData[i + 2]
          count++
        }
        
        // 计算平均值
        r = Math.floor(r / count)
        g = Math.floor(g / count)
        b = Math.floor(b / count)
        
        // 设置主题色
        dominantColor.value = [r, g, b]
      } catch (err) {
        console.error('提取颜色失败:', err)
        useRandomColor()
      }
    }
    img.onerror = () => {
      console.error('图片加载失败')
      useRandomColor()
    }
    img.src = coverUrl
  } catch (err) {
    console.error('提取颜色初始化失败:', err)
    useRandomColor()
  }
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
  
  const progressBar = e.currentTarget
  const rect = progressBar.getBoundingClientRect()
  const percent = (e.clientX - rect.left) / rect.width
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
  showPlaylist.value = false
}

// 切换全屏模式
const toggleFullScreen = () => {
  isFullScreen.value = !isFullScreen.value
}

// 切换播放列表显示
const togglePlaylist = () => {
  showPlaylist.value = !showPlaylist.value
}

// 键盘控制
const handleKeyDown = (e) => {
  if (e.code === 'Space') {
    togglePlay()
    e.preventDefault()
  } else if (e.code === 'ArrowRight') {
    playNext()
  } else if (e.code === 'ArrowLeft') {
    playPrev()
  }
}

// 页面加载时获取音乐数据并添加键盘事件监听
onMounted(() => {
  fetchMusicData()
  window.addEventListener('keydown', handleKeyDown)
})

// 组件卸载时移除事件监听
onUnmounted(() => {
  window.removeEventListener('keydown', handleKeyDown)
})
</script>

<template>
  <div 
    class="music-player" 
    :class="{ 'fullscreen': isFullScreen }"
    :style="!loading && !error && currentTrack ? backgroundStyle : {}"
  >
    <header class="player-header">
      <div class="header-controls">
        <button @click="toggleFullScreen" class="icon-btn">
          <span v-if="isFullScreen">退出全屏</span>
          <span v-else>全屏模式</span>
        </button>
      </div>
    </header>
    
    <div v-if="loading" class="loading">
      <div class="loading-spinner"></div>
      <p>加载音乐列表中...</p>
    </div>
    
    <div v-else-if="error" class="error">
      <p>{{ error }}</p>
      <button @click="fetchMusicData" class="retry-btn">重试</button>
    </div>
    
    <div v-else-if="audioFiles.length > 0" class="player-container">
      <div class="main-content">
        <div class="player-info">
          <div class="cover-container" :class="{ 'large': isFullScreen }">
            <img 
              v-if="currentTrack?.cover" 
              :src="currentTrack.cover" 
              :alt="currentTrack.name" 
              class="cover-image"
            />
            <div v-else class="cover-placeholder"></div>
          </div>
          
          <div class="track-info">
            <h2 class="track-name">{{ currentTrack?.name || '未选择音乐' }}</h2>
            <p class="track-artist">{{ currentTrack?.artist || '未知艺术家' }}</p>
            <p class="track-album">{{ currentTrack?.album || '未知专辑' }}</p>
          </div>
        </div>
        
        <div class="player-controls">
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
          
          <div class="main-controls">
            <button @click="playPrev" class="control-btn prev-btn">
              <svg viewBox="0 0 24 24" width="24" height="24">
                <path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" fill="currentColor"/>
              </svg>
            </button>
            <button @click="togglePlay" class="control-btn play-btn">
              <svg v-if="isPlaying" viewBox="0 0 24 24" width="36" height="36">
                <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" fill="currentColor"/>
              </svg>
              <svg v-else viewBox="0 0 24 24" width="36" height="36">
                <path d="M8 5v14l11-7z" fill="currentColor"/>
              </svg>
            </button>
            <button @click="playNext" class="control-btn next-btn">
              <svg viewBox="0 0 24 24" width="24" height="24">
                <path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z" fill="currentColor"/>
              </svg>
            </button>
          </div>
          
          <div class="extra-controls">
            <div class="volume-control">
              <svg viewBox="0 0 24 24" width="20" height="20">
                <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" fill="currentColor"/>
              </svg>
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
            
            <button @click="togglePlaylist" class="icon-btn playlist-btn">
              <svg viewBox="0 0 24 24" width="24" height="24">
                <path d="M3 13h2v-2H3v2zm0 4h2v-2H3v2zm0-8h2V7H3v2zm4 4h14v-2H7v2zm0 4h14v-2H7v2zM7 7v2h14V7H7z" fill="currentColor"/>
              </svg>
            </button>
          </div>
        </div>
      </div>
      
      <div class="playlist" :class="{ 'active': showPlaylist }">
        <div class="playlist-header">
          <h3>播放列表</h3>
          <button @click="togglePlaylist" class="close-btn">
            <svg viewBox="0 0 24 24" width="24" height="24">
              <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" fill="currentColor"/>
            </svg>
          </button>
        </div>
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
              <div v-else class="track-list-cover placeholder"></div>
              <div class="track-list-info">
                <div class="track-list-name">{{ track.name }}</div>
                <div class="track-list-artist">{{ track.artist }}</div>
              </div>
              <div class="track-list-playing" v-if="currentTrack?.id === track.id">
                <svg v-if="isPlaying" viewBox="0 0 24 24" width="24" height="24">
                  <path d="M8 5.14v14l11-7-11-7z" fill="currentColor"/>
                </svg>
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

<style>
html, body {
  margin: 0;
  padding: 0;
  height: 100%;
  overflow: hidden;
}

body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
  background-color: #000;
  color: #fff;
}
</style>

<style scoped>
.music-player {
  position: relative;
  height: 100vh;
  width: 100%;
  display: flex;
  flex-direction: column;
  transition: background 0.5s ease;
  background: linear-gradient(to bottom, #1c1c1c, #000);
  color: #fff;
  overflow: hidden;
}

.player-header {
  display: flex;
  justify-content: flex-end;
  align-items: center;
  padding: 1rem 2rem;
  z-index: 10;
}

h1 {
  margin: 0;
  font-size: 1.5rem;
  font-weight: 500;
}

.header-controls {
  display: flex;
  gap: 1rem;
}

.icon-btn {
  background: none;
  border: none;
  color: inherit;
  cursor: pointer;
  padding: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0.8;
  transition: opacity 0.2s;
  font-size: 0.875rem;
}

.icon-btn:hover {
  opacity: 1;
}

.loading, .error, .empty-state {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  text-align: center;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid rgba(255, 255, 255, 0.3);
  border-radius: 50%;
  border-top-color: #fff;
  animation: spin 1s ease-in-out infinite;
  margin-bottom: 1rem;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.error {
  color: #ff6b6b;
}

.retry-btn {
  margin-top: 1rem;
  background: rgba(255, 255, 255, 0.1);
  border: none;
  color: #fff;
  padding: 0.5rem 1.5rem;
  border-radius: 4px;
  cursor: pointer;
  transition: background 0.2s;
  font-size: 0.875rem;
}

.retry-btn:hover {
  background: rgba(255, 255, 255, 0.2);
}

.hint {
  color: rgba(255, 255, 255, 0.6);
  font-size: 0.875rem;
  margin-top: 0.5rem;
}

.player-container {
  flex: 1;
  display: flex;
  flex-direction: column;
  padding: 0 2rem 2rem;
  position: relative;
  overflow: hidden;
}

.main-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  max-width: 1200px;
  margin: 0 auto;
  width: 100%;
  position: relative;
  z-index: 1;
}

.player-info {
  display: flex;
  flex-direction: column;
  align-items: center;
  margin-bottom: 2rem;
  width: 100%;
}

.cover-container {
  width: 250px;
  height: 250px;
  margin-bottom: 2rem;
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.3);
  transition: all 0.3s ease;
  overflow: hidden;
}

.cover-container.large {
  width: 350px;
  height: 350px;
}

.cover-image {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.cover-placeholder {
  width: 100%;
  height: 100%;
  background: #333;
  display: flex;
  align-items: center;
  justify-content: center;
}

.track-info {
  text-align: center;
  width: 100%;
  max-width: 600px;
}

.track-name {
  font-size: 2rem;
  font-weight: 700;
  margin: 0 0 0.5rem;
  line-height: 1.2;
}

.track-artist {
  font-size: 1.25rem;
  font-weight: 500;
  margin: 0 0 0.25rem;
  opacity: 0.8;
}

.track-album {
  font-size: 1rem;
  margin: 0;
  opacity: 0.6;
}

.player-controls {
  width: 100%;
  max-width: 800px;
  margin-top: auto;
}

.progress-container {
  width: 100%;
  margin-bottom: 1.5rem;
  cursor: pointer;
}

.progress-bar {
  height: 4px;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 2px;
  overflow: hidden;
  cursor: pointer;
}

.progress {
  height: 100%;
  background: #fff;
  border-radius: 2px;
  transition: width 0.1s linear;
}

.time {
  display: flex;
  justify-content: space-between;
  font-size: 0.75rem;
  margin-top: 0.5rem;
  opacity: 0.7;
}

.main-controls {
  display: flex;
  justify-content: center;
  align-items: center;
  margin-bottom: 1.5rem;
}

.control-btn {
  background: none;
  border: none;
  color: inherit;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.2s;
}

.control-btn:hover {
  transform: scale(1.1);
}

.prev-btn, .next-btn {
  padding: 0 2rem;
}

.play-btn {
  background: rgba(255, 255, 255, 0.2);
  width: 64px;
  height: 64px;
  border-radius: 50%;
  margin: 0 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
}

.extra-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.volume-control {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 1;
}

.volume-control input[type="range"] {
  flex: 0 0 100px;
  height: 4px;
  -webkit-appearance: none;
  background: rgba(255, 255, 255, 0.2);
  border-radius: 2px;
  outline: none;
}

.volume-control input[type="range"]::-webkit-slider-thumb {
  -webkit-appearance: none;
  width: 12px;
  height: 12px;
  background: #fff;
  border-radius: 50%;
  cursor: pointer;
}

.playlist-btn {
  margin-left: 1rem;
}

.playlist {
  position: absolute;
  top: 0;
  right: 0;
  width: 350px;
  height: 100%;
  background: rgba(0, 0, 0, 0.8);
  backdrop-filter: blur(10px);
  transform: translateX(100%);
  transition: transform 0.3s ease;
  z-index: 1000;
  padding: 1.5rem;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

.playlist.active {
  transform: translateX(0);
}

.playlist-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.playlist-header h3 {
  margin: 0;
  font-size: 1.25rem;
  font-weight: 600;
}

.close-btn {
  background: none;
  border: none;
  color: inherit;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0.7;
  transition: opacity 0.2s;
}

.close-btn:hover {
  opacity: 1;
}

.playlist ul {
  list-style: none;
  padding: 0;
  margin: 0;
  overflow-y: auto;
  flex: 1;
}

.playlist li {
  border-radius: 6px;
  cursor: pointer;
  transition: background 0.2s;
  margin-bottom: 0.5rem;
}

.playlist li:hover {
  background: rgba(255, 255, 255, 0.1);
}

.playlist li.active {
  background: rgba(255, 255, 255, 0.15);
}

.track-list-item {
  display: flex;
  align-items: center;
  padding: 0.75rem;
}

.track-list-cover {
  width: 48px;
  height: 48px;
  border-radius: 6px;
  margin-right: 1rem;
  object-fit: cover;
}

.track-list-cover.placeholder {
  background: #333;
}

.track-list-info {
  flex: 1;
  min-width: 0;
}

.track-list-name {
  font-weight: 500;
  margin-bottom: 0.25rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.track-list-artist {
  font-size: 0.875rem;
  opacity: 0.7;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.track-list-playing {
  display: flex;
  align-items: center;
  margin-left: 0.5rem;
  color: #1DB954;
}

@media (max-width: 768px) {
  .player-header {
    padding: 1rem;
  }
  
  .player-container {
    padding: 0 1rem 1rem;
  }
  
  .cover-container {
    width: 200px;
    height: 200px;
  }
  
  .cover-container.large {
    width: 250px;
    height: 250px;
  }
  
  .track-name {
    font-size: 1.5rem;
  }
  
  .track-artist {
    font-size: 1rem;
  }
  
  .playlist {
    width: 280px;
  }
}

@media (max-height: 600px) {
  .cover-container {
    width: 150px;
    height: 150px;
    margin-bottom: 1rem;
  }
  
  .cover-container.large {
    width: 180px;
    height: 180px;
  }
}

/* 全屏模式 */
.fullscreen {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  z-index: 9999;
}
</style>
