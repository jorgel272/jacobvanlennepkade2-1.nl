document.addEventListener('DOMContentLoaded', function() {
    // --- CONFIGURATION ---
    // IMPORTANT: Replace this with your actual Google Cloud Storage bucket name.
    const BUCKET_NAME = 'jacobvanlennepkade2-1-nl-website';
    const FOLDER_NAME = 'photos/';
    // --- END CONFIGURATION ---

    const gallery = document.getElementById('photo-gallery');
    const modal = document.getElementById('gallery-modal');
    const modalImg = document.getElementById('modal-image');
    const closeBtn = document.querySelector('.close');
    const prevBtn = document.querySelector('.prev');
    const nextBtn = document.querySelector('.next');
    
    let imageSources = [];
    let currentIndex;

    // Construct the public API URL to list objects in the bucket
    const apiUrl = `https://storage.googleapis.com/storage/v1/b/${BUCKET_NAME}/o?prefix=${FOLDER_NAME}`;

    // Fetch the list of photos from the GCS bucket
    fetch(apiUrl)
        .then(response => response.json())
        .then(data => {
            gallery.innerHTML = ''; // Clear the "Loading..." message
            if (data.items && data.items.length > 0) {
                data.items.forEach(item => {
                    // Make sure it's a file (not the folder itself) and is an image
                    if (item.size > 0 && /\.(jpe?g|png|gif|webp)$/i.test(item.name)) {
                        const imageUrl = `https://storage.googleapis.com/${BUCKET_NAME}/${item.name}`;
                        imageSources.push(imageUrl);

                        const galleryItem = document.createElement('div');
                        galleryItem.className = 'gallery-item';
                        
                        const img = document.createElement('img');
                        img.src = imageUrl;
                        img.alt = `Photo from our new home`;
                        img.loading = 'lazy'; // Lazy load images for better performance

                        galleryItem.appendChild(img);
                        gallery.appendChild(galleryItem);
                    }
                });
            } else {
                gallery.innerHTML = '<p>No photos found in the gallery.</p>';
            }
        })
        .catch(error => {
            console.error('Error fetching photos:', error);
            gallery.innerHTML = '<p>Sorry, there was an error loading the photos.</p>';
        });

    // --- LIGHTBOX LOGIC (Now uses event delegation) ---
    gallery.addEventListener('click', function(e) {
        if (e.target.tagName === 'IMG') {
            const clickedSrc = e.target.src;
            currentIndex = imageSources.indexOf(clickedSrc);
            modalImg.src = clickedSrc;
            modal.style.display = 'block';
        }
    });

    function closeModal() {
        modal.style.display = 'none';
    }

    function showImage(index) {
        if (index >= imageSources.length) {
            currentIndex = 0;
        } else if (index < 0) {
            currentIndex = imageSources.length - 1;
        } else {
            currentIndex = index;
        }
        modalImg.src = imageSources[currentIndex];
    }
    
    const showNextImage = () => showImage(currentIndex + 1);
    const showPrevImage = () => showImage(currentIndex - 1);
    
    closeBtn.addEventListener('click', closeModal);
    prevBtn.addEventListener('click', showPrevImage);
    nextBtn.addEventListener('click', showNextImage);

    window.addEventListener('click', (event) => {
        if (event.target == modal) closeModal();
    });

    document.addEventListener('keydown', (event) => {
        if (modal.style.display === 'block') {
            if (event.key === 'ArrowRight') showNextImage();
            if (event.key === 'ArrowLeft') showPrevImage();
            if (event.key === 'Escape') closeModal();
        }
    });
});